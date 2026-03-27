#
# last edit: 2026-03-23
package OpenLash::Comm;
use strict;
use warnings;
use Path::Tiny;
use lib path(__FILE__)->parent->parent->stringify;
use Telegram::Bot;
use JSON;
use Data::Dumper;
use threads;  # For non-blocking polling if needed; optional for basic use

sub new {
    my ($class, %args) = @_;
    my $self = bless {
        channels => {},  # Hash: {name => {type => '', config => {}, bot => undef}}
        handlers => $args{handlers} || [],  # Array of callbacks for incoming messages
        default_token => $args{token} || undef,  # Fallback if no per-channel token
    }, $class;
    return $self;
}

sub add_channel {
    my ($self, $name, $type, $config) = @_;
    die "Channel name '$name' already exists" if exists $self->{channels}{$name};
    
    my $channel = { type => $type, config => $config || {} };
    
    if ($type eq 'telegram') {
        my $token = $config->{token} || $self->{default_token};
        die "TELEGRAM_TOKEN missing for channel '$name'!" unless $token;
        $channel->{bot} = Telegram::Bot->new(token => $token);
        $channel->{chat_id} = $config->{chat_id} || 'default';  # Can be array for multi-chat
        $channel->{listen_from} = $config->{listen_from} || 'all';  # 'all' or specific user IDs
    } elsif ($type eq 'cli') {
        # CLI is simple—no extra init
    } elsif ($type eq 'irc') {
        # Stub for IRC (e.g., use Net::IRC); expand as needed
        $channel->{config} = $config;
    } else {
        die "Unknown channel type: $type";
    }
    
    $self->{channels}{$name} = $channel;
    print "Added channel: $name ($type)\n";  # Basic logging
}

sub load_config {
    my ($self, $file) = @_;
    # Basic JSON config loader; expand for YAML/INI if needed
    return unless -e $file;
    open my $fh, '<', $file or die "Can't open config $file: $!";
    local $/; my $json = <$fh>; close $fh;
    my $config = decode_json($json) or die "Invalid JSON in $file";
    
    # Assume config is {connections => [{type => '', token => '', channels => [...] }]}
    foreach my $conn (@{$config->{connections} || []}) {
        my $type = $conn->{type};
        my $token = $conn->{token};
        $self->{default_token} = $token if $token;  # Set global if provided
        
        foreach my $chan (@{$conn->{channels} || []}) {
            $self->add_channel($chan->{name}, $type, { %$chan, token => $token });
        }
    }
    print "Loaded config from $file\n";
}

sub send {
    my ($self, $channel_name, $text, $opts) = @_;
    $opts ||= {};
    my $ch = $self->{channels}{$channel_name} or warn "Channel '$channel_name' not found" and return;
    
    if ($ch->{type} eq 'telegram') {
        my %msg = (
            chat_id => $opts->{chat_id} || $ch->{chat_id},
            text => $text,
            parse_mode => $opts->{parse_mode} || 'HTML',  # Optional: Markdown/HTML
        );
        eval {
            $ch->{bot}->sendMessage(\%msg);
            print "Sent to Telegram ($channel_name): $text\n";
        }; if ($@) { warn "Telegram send error: $@" }
    } elsif ($ch->{type} eq 'cli') {
        print "[$channel_name] $text\n";
    } elsif ($ch->{type} eq 'irc') {
        # Stub: Integrate with IRC client lib here
        warn "IRC send not implemented yet";
    } else {
        warn "Send not supported for type: $ch->{type}";
    }
}

sub register_handler {
    my ($self, $callback) = @_;
    die "Handler must be a code ref" unless ref $callback eq 'CODE';
    push @{$self->{handlers}}, $callback;
    print "Registered handler\n";
}

sub start_listening {
    my $self = shift;
    my $poll_interval = shift || 1;  # Seconds between polls
    
    # Start polling for each Telegram channel in a loop (non-blocking via threads if desired)
    foreach my $name (keys %{$self->{channels}}) {
        my $ch = $self->{channels}{$name};
        next unless $ch->{type} eq 'telegram';
        
        $self->_log_msg("Starting Telegram listener for $name...");
        # Use threads for non-blocking if multiple channels; for simplicity, sequential poll
        while (1) {
            eval {
                my $updates = $ch->{bot}->getUpdates({
                    offset => $ch->{last_update} || 0,
                    timeout => 30,  # Long poll
                    allowed_updates => ['message'],
                });
                
                foreach my $update (@{$updates->{result} || []}) {
                    $ch->{last_update} = $update->{update_id} + 1;
                    next unless $update->{message};
                    my $msg = $update->{message};
                    my $text = $msg->{text};
                    my $chat_id = $msg->{chat}->{id};
                    my $from_id = $msg->{from}->{id};
                    
                    # Filter: listen_from 'all' or match user ID
                    next unless $ch->{listen_from} eq 'all' || (ref $ch->{listen_from} eq 'ARRAY' && grep { $_ eq $from_id } @{$ch->{listen_from}});
                    
                    # Decode and handle (e.g., non-text messages stubbed)
                    if ($text) {
                        $self->_log_msg("Received from Telegram ($name, chat $chat_id, from $from_id): $text");
                        $_->($name, $text, { chat_id => $chat_id, from_id => $from_id }) 
                            for @{$self->{handlers}};
                    } else {
                        my $reply = "Unsupported message type received.";
                        $self->send($name, $reply, { chat_id => $chat_id });
                        $self->_log_msg("Handled non-text message in $name (chat $chat_id): $reply");
                    }
                }
            }; if ($@) { 
                $self->_log_err("Telegram poll error for $name: $@"); 
                warn "Telegram poll error for $name: $@" 
            }
            
            sleep $poll_interval;
        }
    }
    
    # For CLI/IRC: These are event-driven externally; no poll needed here
    $self->_log_msg("Listening started for non-Telegram channels (CLI/IRC).");
}

#1;
# handle (e.g., non-text messages stubbed)
#                    if ($text) {
#                        print "Received from Telegram ($name, chat $chat_id): $text\n";
#                        $_->($name, $text, { chat_id => $chat_id, from_id => $from_id }) 
#                            for @{$self->{handlers}};
#                    } else {
#                        # Handle non-text (e.g., stickers, photos) – stub
#                        $self->send($name, "Unsupported message type received.", { chat_id => $chat_id });
#                    }
#                }
#            }; if ($@) { warn "Telegram poll error for $name: $@" }
#            
#            sleep $poll_interval;
#        }
#    }
#    
#    # For CLI/IRC: These are event-driven externally; no poll needed here
#}

1;
