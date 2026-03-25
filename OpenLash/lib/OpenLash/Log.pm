package OpenLash::Log;
use strict; use warnings;
use POSIX qw(strftime);

our $DEBUG = $ENV{OL_DEBUG} || 0;
our $LOGFILE = $ENV{OL_LOGFILE} || 'openlash.log';

sub OLlog {
    my ($level, $msg) = @_;
    my $time = strftime("%Y-%m-%d %H:%M:%S", localtime);
    my $entry = "[$time] [$level] $msg\n";
    open my $fh, '>>', $LOGFILE or warn "Can't log: $!";
    print $fh $entry;
    close $fh;
    print STDERR $entry if $DEBUG;
}

sub OLinfo {
    OLlog('INFO', @_);
}

sub OLdebug {
    OLlog('DEBUG', @_) if $DEBUG;
}

1;