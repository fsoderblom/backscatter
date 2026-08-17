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
# whitelist_ctl.pl: manage whitelist_rules/whitelist_cidrs/whitelist_port_predicates
#
# Connects as the 'whitelist' user (see doc/grants.sql), a separate [whitelist]
# stanza in /home/scatter/.my.cnf from the daemon's own 'backscatter' user -- the
# daemon only ever reads these tables, so it has no write grant on them.
#
# The 'test' command reimplements backscatter's load_whitelist()/whitelist_match()/
# _port_predicate() (see /opt/backscatter/sbin/backscatter) so a rule can be checked
# before it goes live. If that matching logic ever changes, update load_rules() and
# port_predicate_match() below to match.
#
# When       Who                What
# 2026-08-16 fredrik@xpd.se     created.

use strict;
use warnings;
use DBI;
use Getopt::Long qw(GetOptionsFromArray);
use Net::CIDR;

my $dsn            = 'dbi:mysql:backscatter';
my $defaults_file  = '/home/scatter/.my.cnf';
my $defaults_group = 'whitelist';

my @VALID_PROTO     = qw(TCP UDP ICMP ESP AH);
my @VALID_ACTION    = qw(whitelist drop_event);
my @VALID_OPERATOR  = qw(eq gt ge lt le);

my ($reason, $action, $proto, $priority, $comment);
my (@src_cidrs, @dst_cidrs, @add_src_cidrs, @add_dst_cidrs, @remove_src_cidrs, @remove_dst_cidrs);
my (@src_ports, @dst_ports, @add_src_ports, @add_dst_ports, @remove_src_ports, @remove_dst_ports);
my ($enabled_only, $yes, $reload, $help);
my ($t_srcip, $t_srcport, $t_dstip, $t_dstport);

my $command = (@ARGV && $ARGV[0] !~ /^-/) ? shift @ARGV : undef;

GetOptionsFromArray(\@ARGV,
    'dsn=s'              => \$dsn,
    'defaults-file=s'    => \$defaults_file,
    'defaults-group=s'   => \$defaults_group,
    'reload'             => \$reload,
    'yes'                => \$yes,
    'enabled-only'       => \$enabled_only,
    'reason=s'           => \$reason,
    'action=s'           => \$action,
    'proto=s'            => \$proto,
    'priority=i'         => \$priority,
    'comment=s'          => \$comment,
    'src-cidr=s@'        => \@src_cidrs,
    'dst-cidr=s@'        => \@dst_cidrs,
    'add-src-cidr=s@'    => \@add_src_cidrs,
    'add-dst-cidr=s@'    => \@add_dst_cidrs,
    'remove-src-cidr=s@' => \@remove_src_cidrs,
    'remove-dst-cidr=s@' => \@remove_dst_cidrs,
    'src-port=s@'        => \@src_ports,
    'dst-port=s@'        => \@dst_ports,
    'add-src-port=s@'    => \@add_src_ports,
    'add-dst-port=s@'    => \@add_dst_ports,
    'remove-src-port=s@' => \@remove_src_ports,
    'remove-dst-port=s@' => \@remove_dst_ports,
    'srcip=s'            => \$t_srcip,
    'srcport=i'          => \$t_srcport,
    'dstip=s'            => \$t_dstip,
    'dstport=i'          => \$t_dstport,
    'help'               => \$help,
) or usage(2);

usage(0) if $help;
usage(2, 'Specify a command') unless defined $command;

my %dispatch = (
    list    => \&cmd_list,
    show    => \&cmd_show,
    add     => \&cmd_add,
    edit    => \&cmd_edit,
    enable  => sub { cmd_toggle(1, @_) },
    disable => sub { cmd_toggle(0, @_) },
    delete  => \&cmd_delete,
    test    => \&cmd_test,
);

usage(2, "Unknown command '$command'") unless exists $dispatch{$command};

my $dbh = DBI->connect($dsn, undef, undef, {
    RaiseError => 1,
    PrintError => 0,
    AutoCommit => 1,
    mysql_read_default_file  => $defaults_file,
    mysql_read_default_group => $defaults_group,
}) or die "Database connection failed: $DBI::errstr\n";

$dispatch{$command}->($dbh);

$dbh->disconnect;
exit 0;

#
# Commands
#

sub cmd_list {
    my ($dbh) = @_;

    my $sql = 'SELECT id, priority, enabled, action, proto, reason FROM whitelist_rules';
    $sql .= ' WHERE enabled=1' if $enabled_only;
    $sql .= ' ORDER BY priority, id';

    my $rows = $dbh->selectall_arrayref($sql, { Slice => {} });
    unless (@$rows) {
        print "No whitelist rules.\n";
        return;
    }

    printf "%-5s %-9s %-8s %-11s %-6s %s\n", 'id', 'priority', 'enabled', 'action', 'proto', 'reason';
    for my $r (@$rows) {
        printf "%-5s %-9s %-8s %-11s %-6s %s\n",
            $r->{id}, $r->{priority}, ($r->{enabled} ? 'yes' : 'no'),
            $r->{action}, ($r->{proto} // '*'), $r->{reason};
    }
}

sub cmd_show {
    my ($dbh) = @_;
    my $id = shift @ARGV;
    usage(2, 'show requires a rule id') unless defined $id && $id =~ /^\d+$/;

    my $r = $dbh->selectrow_hashref('SELECT * FROM whitelist_rules WHERE id=?', undef, $id);
    die "No such rule: $id\n" unless $r;

    print "id:       $r->{id}\n";
    print "priority: $r->{priority}\n";
    print "enabled:  " . ($r->{enabled} ? 'yes' : 'no') . "\n";
    print "action:   $r->{action}\n";
    print "proto:    " . ($r->{proto} // '*') . "\n";
    print "reason:   $r->{reason}\n";
    print "comment:  " . ($r->{comment} // '') . "\n";
    print "created:  $r->{created_at}\n";
    print "updated:  $r->{updated_at}\n";

    my $cidrs = $dbh->selectall_arrayref(
        'SELECT direction, cidr FROM whitelist_cidrs WHERE rule_id=? ORDER BY direction, cidr',
        { Slice => {} }, $id
    );
    print "cidrs:\n";
    print "  (none)\n" unless @$cidrs;
    print "  $_->{direction}: $_->{cidr}\n" for @$cidrs;

    my $ports = $dbh->selectall_arrayref(
        'SELECT direction, comparison, operator, operand FROM whitelist_port_predicates WHERE rule_id=? ORDER BY direction, operand',
        { Slice => {} }, $id
    );
    print "ports:\n";
    print "  (none)\n" unless @$ports;
    print "  $_->{direction}: $_->{comparison} $_->{operator} $_->{operand}\n" for @$ports;
}

sub cmd_add {
    my ($dbh) = @_;

    usage(2, '--reason is required and must be 1-255 characters')
      unless defined $reason && length($reason) >= 1 && length($reason) <= 255;

    $action //= 'whitelist';
    usage(2, "--action must be one of: @VALID_ACTION") unless grep { $_ eq $action } @VALID_ACTION;

    if (defined $proto) {
        $proto = uc $proto;
        usage(2, "--proto must be one of: @VALID_PROTO") unless grep { $_ eq $proto } @VALID_PROTO;
    }

    usage(2, '--priority must be between 0 and 65535')
      if defined $priority && ($priority < 0 || $priority > 65535);

    usage(2, '--comment must be at most 500 characters')
      if defined $comment && length($comment) > 500;

    my @cidr_rows;
    for my $cidr (@src_cidrs) {
        die "invalid CIDR '$cidr'\n" unless Net::CIDR::cidrvalidate($cidr);
        push @cidr_rows, ['src', $cidr];
    }
    for my $cidr (@dst_cidrs) {
        die "invalid CIDR '$cidr'\n" unless Net::CIDR::cidrvalidate($cidr);
        push @cidr_rows, ['dst', $cidr];
    }

    my @port_rows;
    push @port_rows, ['src', parse_port_spec($_)] for @src_ports;
    push @port_rows, ['dst', parse_port_spec($_)] for @dst_ports;

    if (!@cidr_rows && !@port_rows && !defined $proto && !$yes) {
        usage(2, "refusing to add a rule with no --proto, --src-cidr/--dst-cidr or " .
                 "--src-port/--dst-port: it would match ALL traffic. Pass --yes to add it anyway.");
    }

    if (defined $priority) {
        my ($exists) = $dbh->selectrow_array('SELECT 1 FROM whitelist_rules WHERE priority=?', undef, $priority);
        die "priority $priority is already used by another rule (see 'list')\n" if $exists;
    } else {
        ($priority) = $dbh->selectrow_array('SELECT COALESCE(MAX(priority),0)+10 FROM whitelist_rules');
    }

    my $id;
    eval {
        $dbh->begin_work;

        $dbh->do(
            'INSERT INTO whitelist_rules (priority,reason,action,proto,comment) VALUES (?,?,?,?,?)',
            undef, $priority, $reason, $action, $proto, $comment
        );
        $id = $dbh->last_insert_id(undef, undef, 'whitelist_rules', 'id');

        my $cidr_sth = $dbh->prepare('INSERT INTO whitelist_cidrs (rule_id,direction,cidr) VALUES (?,?,?)');
        $cidr_sth->execute($id, $_->[0], $_->[1]) for @cidr_rows;

        my $port_sth = $dbh->prepare(
            'INSERT INTO whitelist_port_predicates (rule_id,direction,comparison,operator,operand) VALUES (?,?,?,?,?)'
        );
        $port_sth->execute($id, $_->[0], $_->[1]{comparison}, $_->[1]{operator}, $_->[1]{operand}) for @port_rows;

        $dbh->commit;
        1;
    } or do {
        my $err = $@ || 'unknown error';
        $dbh->rollback;
        die "Failed to add rule: $err";
    };

    print "Added rule #$id (priority $priority): $reason\n";
    maybe_reload();
}

sub cmd_edit {
    my ($dbh) = @_;
    my $id = shift @ARGV;
    usage(2, 'edit requires a rule id') unless defined $id && $id =~ /^\d+$/;

    my $existing = $dbh->selectrow_hashref('SELECT * FROM whitelist_rules WHERE id=?', undef, $id);
    die "No such rule: $id\n" unless $existing;

    if (defined $action) {
        usage(2, "--action must be one of: @VALID_ACTION") unless grep { $_ eq $action } @VALID_ACTION;
    }
    if (defined $proto) {
        $proto = uc $proto;
        usage(2, "--proto must be one of: @VALID_PROTO") unless grep { $_ eq $proto } @VALID_PROTO;
    }
    usage(2, '--priority must be between 0 and 65535')
      if defined $priority && ($priority < 0 || $priority > 65535);
    usage(2, '--reason must be 1-255 characters')
      if defined $reason && (length($reason) < 1 || length($reason) > 255);
    usage(2, '--comment must be at most 500 characters')
      if defined $comment && length($comment) > 500;

    if (defined $priority && $priority != $existing->{priority}) {
        my ($exists) = $dbh->selectrow_array(
            'SELECT 1 FROM whitelist_rules WHERE priority=? AND id<>?', undef, $priority, $id
        );
        die "priority $priority is already used by another rule\n" if $exists;
    }

    for my $cidr (@add_src_cidrs, @add_dst_cidrs) {
        die "invalid CIDR '$cidr'\n" unless Net::CIDR::cidrvalidate($cidr);
    }
    my @add_port_rows;
    push @add_port_rows, ['src', parse_port_spec($_)] for @add_src_ports;
    push @add_port_rows, ['dst', parse_port_spec($_)] for @add_dst_ports;

    eval {
        $dbh->begin_work;

        my %fields = (reason => $reason, action => $action, proto => $proto,
                      priority => $priority, comment => $comment);
        my (@set, @bind);
        for my $field (qw(reason action proto priority comment)) {
            next unless defined $fields{$field};
            push @set, "$field=?";
            push @bind, $fields{$field};
        }
        if (@set) {
            $dbh->do('UPDATE whitelist_rules SET ' . join(',', @set) . ' WHERE id=?', undef, @bind, $id);
        }

        my $cidr_ins = $dbh->prepare('INSERT INTO whitelist_cidrs (rule_id,direction,cidr) VALUES (?,?,?)');
        $cidr_ins->execute($id, 'src', $_) for @add_src_cidrs;
        $cidr_ins->execute($id, 'dst', $_) for @add_dst_cidrs;

        my $cidr_del = $dbh->prepare('DELETE FROM whitelist_cidrs WHERE rule_id=? AND direction=? AND cidr=?');
        for my $cidr (@remove_src_cidrs) {
            warn "warning: src CIDR '$cidr' was not present on rule $id\n"
              if $cidr_del->execute($id, 'src', $cidr) == 0;
        }
        for my $cidr (@remove_dst_cidrs) {
            warn "warning: dst CIDR '$cidr' was not present on rule $id\n"
              if $cidr_del->execute($id, 'dst', $cidr) == 0;
        }

        my $port_ins = $dbh->prepare(
            'INSERT INTO whitelist_port_predicates (rule_id,direction,comparison,operator,operand) VALUES (?,?,?,?,?)'
        );
        for my $row (@add_port_rows) {
            $port_ins->execute($id, $row->[0], $row->[1]{comparison}, $row->[1]{operator}, $row->[1]{operand});
        }

        my $port_del = $dbh->prepare(
            'DELETE FROM whitelist_port_predicates WHERE rule_id=? AND direction=? AND comparison=? AND operator=? AND operand=?'
        );
        for my $spec (@remove_src_ports) {
            my $p = parse_port_spec($spec);
            warn "warning: src port predicate '$spec' was not present on rule $id\n"
              if $port_del->execute($id, 'src', $p->{comparison}, $p->{operator}, $p->{operand}) == 0;
        }
        for my $spec (@remove_dst_ports) {
            my $p = parse_port_spec($spec);
            warn "warning: dst port predicate '$spec' was not present on rule $id\n"
              if $port_del->execute($id, 'dst', $p->{comparison}, $p->{operator}, $p->{operand}) == 0;
        }

        $dbh->commit;
        1;
    } or do {
        my $err = $@ || 'unknown error';
        $dbh->rollback;
        die "Failed to edit rule: $err";
    };

    print "Updated rule #$id.\n";
    maybe_reload();
}

sub cmd_toggle {
    my ($enabled, $dbh) = @_;
    my $id = shift @ARGV;
    usage(2, ($enabled ? 'enable' : 'disable') . ' requires a rule id') unless defined $id && $id =~ /^\d+$/;

    my $n = $dbh->do('UPDATE whitelist_rules SET enabled=? WHERE id=?', undef, $enabled, $id);
    die "No such rule: $id\n" if $n == 0;

    print 'Rule #' . $id . ' ' . ($enabled ? 'enabled' : 'disabled') . ".\n";
    maybe_reload();
}

sub cmd_delete {
    my ($dbh) = @_;
    my $id = shift @ARGV;
    usage(2, 'delete requires a rule id') unless defined $id && $id =~ /^\d+$/;

    my $r = $dbh->selectrow_hashref('SELECT * FROM whitelist_rules WHERE id=?', undef, $id);
    die "No such rule: $id\n" unless $r;

    unless ($yes) {
        print "Would delete rule #$id (priority $r->{priority}): $r->{reason}\n";
        print "(and its associated CIDRs/port predicates, via cascade)\n";
        print "Pass --yes to actually delete it.\n";
        return;
    }

    $dbh->do('DELETE FROM whitelist_rules WHERE id=?', undef, $id); # cascades to cidrs/ports
    print "Deleted rule #$id.\n";
    maybe_reload();
}

sub cmd_test {
    my ($dbh) = @_;
    usage(2, 'test requires --proto, --srcip, --srcport, --dstip and --dstport')
      unless defined $proto && defined $t_srcip && defined $t_srcport
          && defined $t_dstip && defined $t_dstport;

    my $rules = load_rules($dbh);
    for my $r (@$rules) {
        next if defined($r->{proto}) && uc($proto) ne uc($r->{proto});
        next if @{$r->{cidrs}{src}} && !Net::CIDR::cidrlookup($t_srcip, @{$r->{cidrs}{src}});
        next if @{$r->{cidrs}{dst}} && !Net::CIDR::cidrlookup($t_dstip, @{$r->{cidrs}{dst}});
        next if @{$r->{ports}{src}} && !grep { port_predicate_match($t_srcport, $_) } @{$r->{ports}{src}};
        next if @{$r->{ports}{dst}} && !grep { port_predicate_match($t_dstport, $_) } @{$r->{ports}{dst}};
        print "MATCH rule #$r->{id} (priority $r->{priority}): reason='$r->{reason}' action=$r->{action}\n";
        return;
    }
    print "NO MATCH (would be treated as a candidate)\n";
}

#
# Helpers
#

# Mirrors backscatter's load_whitelist() so 'test' evaluates rules identically to the daemon.
sub load_rules {
    my ($dbh) = @_;
    my @rules;
    my $sth = $dbh->prepare(q{
        SELECT id, priority, reason, action, proto
          FROM whitelist_rules WHERE enabled=1 ORDER BY priority, id
    });
    $sth->execute;
    while (my $r = $sth->fetchrow_hashref) {
        $r->{cidrs} = { src => [], dst => [] };
        $r->{ports} = { src => [], dst => [] };

        my $c = $dbh->prepare('SELECT direction,cidr FROM whitelist_cidrs WHERE rule_id=? ORDER BY direction,cidr');
        $c->execute($r->{id});
        while (my ($d, $cidr) = $c->fetchrow_array) {
            push @{$r->{cidrs}{$d}}, $cidr;
        }

        my $p = $dbh->prepare(
            'SELECT direction,comparison,operator,operand FROM whitelist_port_predicates WHERE rule_id=? ORDER BY direction,operand'
        );
        $p->execute($r->{id});
        while (my ($d, $cmp, $op, $operand) = $p->fetchrow_array) {
            push @{$r->{ports}{$d}}, [$cmp, $op, $operand];
        }

        push @rules, $r;
    }
    return \@rules;
}

# Mirrors backscatter's _port_predicate().
sub port_predicate_match {
    my ($value, $p) = @_;
    my ($cmp, $op, $operand) = @$p;
    if ($cmp eq 'lexical') {
        return $value eq $operand if $op eq 'eq';
        return $value gt $operand if $op eq 'gt';
        return $value ge $operand if $op eq 'ge';
        return $value lt $operand if $op eq 'lt';
        return $value le $operand if $op eq 'le';
    } else {
        return $value == $operand if $op eq 'eq';
        return $value >  $operand if $op eq 'gt';
        return $value >= $operand if $op eq 'ge';
        return $value <  $operand if $op eq 'lt';
        return $value <= $operand if $op eq 'le';
    }
    die "unknown port operator $op";
}

# Parses "OPERATOR:VALUE" or "lexical:OPERATOR:VALUE" into {comparison,operator,operand}.
sub parse_port_spec {
    my ($spec) = @_;
    my @parts = split /:/, $spec;

    my $comparison = 'numeric';
    if (@parts == 3 && lc($parts[0]) eq 'lexical') {
        $comparison = 'lexical';
        shift @parts;
    }
    die "invalid port spec '$spec' (expected OPERATOR:VALUE or lexical:OPERATOR:VALUE)\n" unless @parts == 2;

    my ($operator, $operand) = @parts;
    $operator = lc $operator;
    die "invalid port operator '$operator' (expected one of: @VALID_OPERATOR)\n"
      unless grep { $_ eq $operator } @VALID_OPERATOR;

    if ($comparison eq 'numeric') {
        die "invalid numeric port operand '$operand' (expected 0-65535)\n"
          unless $operand =~ /^\d+$/ && $operand <= 65535;
    } else {
        die "invalid lexical port operand '$operand' (must be 1-5 characters)\n"
          if length($operand) < 1 || length($operand) > 5;
    }

    return { comparison => $comparison, operator => $operator, operand => $operand };
}

sub maybe_reload {
    unless ($reload) {
        print "(pass --reload, or run 'sudo systemctl reload backscatter.service', to apply this immediately)\n";
        return;
    }
    system('sudo', '/usr/bin/systemctl', 'reload', 'backscatter.service');
    if ($? == 0) {
        print "Reloaded backscatter.service.\n";
    } else {
        warn "warning: failed to reload backscatter.service (exit code $?)\n";
    }
}

sub usage {
    my ($exit, $error) = @_;
    warn "$error\n\n" if defined $error;
    print <<'USAGE';
Usage:
  whitelist_ctl.pl <command> [options]

Commands:
  list                                     List whitelist rules
  show <id>                                Show a rule's CIDRs and port predicates
  add       --reason=... [options]         Add a new rule
  edit <id> [options]                      Edit an existing rule
  enable <id>                              Enable a rule
  disable <id>                             Disable a rule (without deleting it)
  delete <id> [--yes]                      Delete a rule (and its CIDRs/ports)
  test --proto=P --srcip=I --srcport=P --dstip=I --dstport=P
                                            Show which rule (if any) matches

Options for 'add' and 'edit':
  --reason TEXT           Human-readable reason (required for add)
  --action ACTION         whitelist|drop_event (default: whitelist)
  --proto PROTO           TCP|UDP|ICMP|ESP|AH (default: any)
  --priority N            Evaluation order, lower first (default: next free, +10)
  --comment TEXT          Free-text comment
  --src-cidr CIDR         Source CIDR to match       ('add', repeatable)
  --dst-cidr CIDR         Destination CIDR to match  ('add', repeatable)
  --src-port SPEC         Source port predicate      ('add', repeatable)
  --dst-port SPEC         Destination port predicate ('add', repeatable)

Additional options for 'edit':
  --add-src-cidr CIDR / --remove-src-cidr CIDR
  --add-dst-cidr CIDR / --remove-dst-cidr CIDR
  --add-src-port SPEC / --remove-src-port SPEC
  --add-dst-port SPEC / --remove-dst-port SPEC

Port predicate SPEC format: OPERATOR:VALUE, or lexical:OPERATOR:VALUE
  OPERATOR is one of: eq gt ge lt le

Other options:
  --enabled-only          ('list' only) hide disabled rules
  --yes                   Skip confirmation ('delete'), or allow an
                           unrestricted rule ('add')
  --reload                Reload the running backscatter daemon (SIGHUP via
                           systemctl) after a successful change
  --dsn DSN               Default: dbi:mysql:backscatter
  --defaults-file FILE    Default: /home/scatter/.my.cnf
  --defaults-group GROUP  Default: backscatter
  --help

Examples:
  whitelist_ctl.pl list
  whitelist_ctl.pl add --reason 'srcip/me' --src-cidr 10.1.2.3/32 --reload
  whitelist_ctl.pl add --reason 'ntp' --proto UDP --src-port eq:123 --reload
  whitelist_ctl.pl edit 7 --add-dst-cidr 203.0.113.0/24 --reload
  whitelist_ctl.pl test --proto TCP --srcip 10.1.2.4 --srcport 51000 \
      --dstip 2.249.46.160 --dstport 443
  whitelist_ctl.pl disable 7 --reload
USAGE
    exit($exit // 0);
}
