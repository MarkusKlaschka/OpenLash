#
#
#
use strict;
use warnings;
use lib './';
use Data::Dumper;
use OpenLash::Server;
use OpenLash;

use constant true  => 0;
use constant false => 1;

# TODO: load CONFIG... set variables...

my $connections;
$connections->[0]->{type} = 'telegram';
$connections->[0]->{token} = "TOKEN";
$connections->[0]->{users} = { USER_ID=>15, OTHER_BOT_ID=>7};

#$connections->[1]->{type} = 'telegram2';
#$connections->[1]->{token} = "TOKEN2";
#$connections->[1]->{users} = { USER_ID2=>15, OTHER_BOT_ID2=>7};

my $channels;
$channels->[0] = {
	name		=>"OpenLashTeam",
	provider	=> 'telegram',
	type		=> 'private',
	listen_msg	=> 'all',
	listen_from	=> 'all',
	react_mode	=> 1,
	perms		=> [
		MorganCarter => {
			read_mem_short	=> true,
			read_mem_long	=> true,
			save_mem_short	=> true,
			save_mem_long	=> true,
			exec_syscmd	=> true,
			call_ext_api	=> true,
			update_home	=> true,
			dynload_skills	=> true,
			dynload_plugins	=> true,
			dynload_tools	=> true,
		}
	],
	skills => ['git', 'team'],
	plugins => [],
	tools => [],
	model_access => ['*'],
	foo=>"bar"
};
#$connections->[0]->{channels} = {};
$connections->[0]->{channels} = $channels;
#$connections->[1]->{channels} = @{$channels};

my $comms = [];  # Initialize as array ref
my $ci = 0;
foreach my $c (@{$connections}) {
    print "CI:$ci:".Dumper(\$c);
    my @_channels = @{$c->{channels} || []};  # Ensure array ref
    foreach my $chan (@_channels) {
        $comms->[$ci++] = OpenLash::Comm->new(
            name => $c->{name} || "conn_$ci",
            type => $c->{type},
            token => $c->{token},
            chat_id => $chan->{chat_id} || $ci  # Use channel-specific if available
        );
    }
}
print "COMMS:\n";
print Dumper(\$comms);  # Remove die for production

my $agent = OpenLash->new(
    ws => '/tmp/OpenLash',
    comm => $comm,
    default_channel => 'OpenLashTeam'
);

my $server = OpenLash::Server->new(agent => $agent);
$server->start;
mms);
my $server = OpenLash::Server->new(agent => $agent);
$server->start;
