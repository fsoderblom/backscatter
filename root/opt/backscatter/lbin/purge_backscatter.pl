#!/usr/bin/perl
#
# Copyright © (2006-2026) Fredrik Söderblom <fredrik@xpd.se>
#
# This file is part of Backscatter.
#
# Backscatter is free software: you can redistribute it and/or modify it under the terms of the
# GNU Affero General Public License as published by the Free Software Foundation, either
# version 3 of the License, or (at your option) any later version.
#
# Backscatter is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License along with
# Backscatter. If not, see <https://www.gnu.org/licenses/>.
#
# feed-routes.sh: feed routes to backscatter AnyIP listener
#
# When       Who                What
# 2026-08-12 fredrik@xpd.se     created.

use strict;
use warnings;
use DBI;
use Getopt::Long qw(GetOptions);
use POSIX qw(strftime);

my $dsn            = 'dbi:mysql:backscatter';
my $defaults_file  = '/home/scatter/.my.cnf';
my $defaults_group = 'backscatter';
my $state_days;
my $matches_days;
my $batch_size = 10_000;
my $dry_run    = 0;
my $help       = 0;

GetOptions(
    'state-days=i'     => \$state_days,
    'matches-days=i'   => \$matches_days,
    'batch-size=i'     => \$batch_size,
    'dsn=s'            => \$dsn,
    'defaults-file=s'  => \$defaults_file,
    'defaults-group=s' => \$defaults_group,
    'dry-run'          => \$dry_run,
    'help'             => \$help,
) or usage(2);

usage(0) if $help;
usage(2, 'Specify --state-days, --matches-days, or both')
  unless defined($state_days) || defined($matches_days);

for my $item (
    ['state-days',   $state_days],
    ['matches-days', $matches_days],
) {
    next unless defined $item->[1];
    usage(2, "--$item->[0] must be at least 1") if $item->[1] < 1;
}
usage(2, '--batch-size must be between 1 and 100000')
  if $batch_size < 1 || $batch_size > 100_000;

my $dbh = DBI->connect($dsn, undef, undef, {
    RaiseError => 1,
    PrintError => 0,
    AutoCommit => 1,
    mysql_read_default_file  => $defaults_file,
    mysql_read_default_group => $defaults_group,
}) or die "Database connection failed: $DBI::errstr\n";

my @jobs;
push @jobs, {
    table  => 'state',
    column => 'last_seen',
    days   => $state_days,
} if defined $state_days;
push @jobs, {
    table  => 'matches',
    column => 'timestamp',
    days   => $matches_days,
} if defined $matches_days;

print 'Started ', strftime('%Y-%m-%d %H:%M:%S %z', localtime), "\n";

for my $job (@jobs) {
    my ($table, $column, $days) = @{$job}{qw(table column days)};

    # Let the database calculate the cutoff in its own session time zone, then
    # reuse that exact value for counting and every delete batch.
    my ($cutoff) = $dbh->selectrow_array(
        'SELECT CURRENT_TIMESTAMP - INTERVAL ? DAY', undef, $days
    );

    # Identifiers come only from the fixed job list above. The cutoff is bound.
    my ($count) = $dbh->selectrow_array(
        "SELECT COUNT(*) FROM `$table` " .
        "WHERE `$column` < ?",
        undef,
        $cutoff,
    );

    printf "%s: %d row(s) older than %d day(s)%s\n",
      $table, $count, $days, ($dry_run ? ' (dry run)' : '');
    next if $dry_run || !$count;

    my $deleted_total = 0;
    while (1) {
        # LIMIT cannot be a portable DBI placeholder here, so batch_size is
        # strictly range-checked above before interpolation.
        my $deleted = $dbh->do(
            "DELETE FROM `$table` " .
            "WHERE `$column` < ? " .
            "LIMIT $batch_size",
            undef,
            $cutoff,
        );
        $deleted = 0 + ($deleted || 0);
        $deleted_total += $deleted;
        print "$table: deleted $deleted_total row(s)\n";
        last if $deleted < $batch_size;
    }
}

$dbh->disconnect;
print 'Finished ', strftime('%Y-%m-%d %H:%M:%S %z', localtime), "\n";

sub usage {
    my ($exit, $error) = @_;
    warn "$error\n\n" if defined $error;
    print <<'USAGE';
Usage:
  purge_backscatter.pl [options]

Required (at least one):
  --state-days N       Delete state rows whose last_seen is older than N days
  --matches-days N     Delete matches rows whose timestamp is older than N days

Options:
  --batch-size N       Rows per DELETE, default 10000, maximum 100000
  --dry-run            Count matching rows without deleting them
  --dsn DSN            Default: dbi:mysql:backscatter
  --defaults-file FILE Default: /home/scatter/.my.cnf
  --defaults-group G   Default: backscatter
  --help

Examples:
  purge_backscatter.pl --state-days 90 --matches-days 30 --dry-run
  purge_backscatter.pl --state-days 90 --matches-days 30
USAGE
    exit($exit // 0);
}
