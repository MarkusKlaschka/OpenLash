package OpenLash::Comm;
use strict; use warnings;
use JSON::PP qw(decode_json);

sub new {
 my ($class, %args) = @_;
 my $self = bless {
 channels => {},
 memory => $args{memory},
 }, $class;
 return $self;
}

sub load_config {
 my ($self, $file) = @_;
 my $data = decode_json(path($file)->slurp);
 $self->add_channel($_->{name}, $_->{type}, $_->{config}) for @{$data->{channels} || []};
}

sub add_channel {
 my ($self, $name, $type, $config) = @_;
 $self->{channels}{$name} = { type => $type, config => $config };
}

=head2 send(...)

Future hook for Telegram/Discord. Currently STDOUT only.

=cut

sub send {
 my ($self, $channel, $message) = @_;
 my $ch = $self->{channels}{$channel} or { OLlog('ERROR', "Channel $channel not found"); return };
 # Stub: print for now
 print "[$channel] $message\n";
 OLinfo("Sent message to $channel");
 # Extend for real Telegram, etc.
}

my %COMMANDOS = (
 nml => \&_cmd_nml, # list all (with active status)
 nmla => \&_cmd_nmla, # list only active
 nma => \&_cmd_nma, # activate
 nmd => \&_cmd_nmd, # deactivate
 # ← future commandos go here as one-liners
);

sub handle_message {
 my ($self, $channel, $input) = @_;

 return unless defined $input && $input =~ s/^\s*\/(\w+)(?:\s+(.*))?\s*$//;
 my ($cmd, $arg) = (lc $1, $2 // '');

 if (my $handler = $COMMANDOS{$cmd}) {
 my $result = $self->$handler($arg);
 $self->send($channel, $result); # always reply via existing send()
 return 1; # consumed
 }
 return 0; # not a commando → pass to OpenLash->ask()
}

sub _cmd_nml { $_[0]->{memory}->nm_list(all => 1) }
sub _cmd_nmla { $_[0]->{memory}->nm_list(active => 1) }
sub _cmd_nma { $_[0]->{memory}->nm_toggle($_[1], 1) }
=head2 _cmd_nmd(arg)

Deactivates named memory.

=cut

sub _cmd_nmd { $_[0]->{memory}->nm_toggle($_[1], 0) }

1;>{memory}->nm_toggle($_[1], 0) }

1;) }

1;d_nma { $_[0]->{memory}->nm_toggle($_[1], 1) }
sub _cmd_nmd { $_[0]->{memory}->nm_toggle($_[1], 0) }

1;>{memory}->nm_toggle($_[1], 0) }

1;