package OpenLash;
use strict; use warnings;
use Path::Tiny;
use DBI;
use lib './';
use OpenLash::LLM;
use OpenLash::Comm;
use OpenLash::Skills;
use OpenLash::Plugins;
use Data::Dumper;

sub new {
    my ($class, %args) = @_;
    my $self = bless {
        ws => path($args{workspace} || "$ENV{HOME}/.OpenLash"),
        skills => $args{skills_obj} || OpenLash::Skills->new(ws => $args{workspace}),
        plugins => $args{plugins_obj} || OpenLash::Plugins->new(),
        max_hist => $args{max_history} || 25,
        llm => $args{llm} || OpenLash::LLM->new(),
        comm => $args{comm} || OpenLash::Comm->new(),
        default_channel => $args{default_channel} || 'cli',
    }, $class;

    $self->{ws}->mkpath;
    $self->{ws}->child("skills")->mkpath;
    $self->_init_db;

    # Register plugins with agent
    $self->{plugins}->register_all($self);

    return $self;
}

sub _init_db {
	my $self = shift;
	$self->{dbh} = DBI->connect("dbi:SQLite:dbname=" . $self->{ws}->child("history.db"), "", "", {RaiseError => 1});
	$self->{dbh}->do("CREATE TABLE IF NOT EXISTS history (id INTEGER PRIMARY KEY, role TEXT, content TEXT, ts DATETIME DEFAULT CURRENT_TIMESTAMP)");
}

sub _log {
	my ($self, $role, $content) = @_;
	$self->{dbh}->do("INSERT INTO history (role, content) VALUES (?, ?)", undef, $role, $content);
}

sub _get_history {
	my $self = shift;
	my $rows = $self->{dbh}->selectall_arrayref("SELECT role, content FROM history ORDER BY id DESC LIMIT ?", undef, $self->{max_hist});
	return reverse @$rows;
}

# Prompt-Bau exakt wie OpenClaw (Dateien + Skills + History)
sub build_prompt {
	my $self = shift;
	my $p = "";

	for my $f (qw(SOUL.md AGENTS.md TOOLS.md)) {
		my $file = $self->{ws}->child($f);
		$p .= $file->slurp . "\n\n" if $file->exists;
	}

	for my $skill (@{$self->{skills}}) {
		my $file = $self->{ws}->child("skills/$skill/SKILL.md");
		$p .= $file->slurp . "\n\n" if $file->exists;
	}

	$p .= join("\n", map { "$_->[0]: $_->[1]" } $self->_get_history());
	return $p;
}

# Minimale Tools (einfach erweiterbar)
sub run_tool {
	my ($self, $name, $args) = @_;
	return ` $args->{cmd} 2>&1 ` if $name eq "shell";
	return $self->{ws}->child($args->{path})->slurp if $name eq "read";
	$self->{ws}->child($args->{path})->spew($args->{content}), return "OK" if $name eq "write";
	$self->_log("reflect", $args->{summary}), return "OK" if $name eq "reflect";
	return "Tool unbekannt";
}

# Haupt-ReAct-Loop (verwendet das injizierte LLM)
sub ask {
	my ($self, $question, $model_name) = @_;
	$self->_log("user", $question);

	my @messages = ({role => "user", content => $question});
	my $system   = $self->build_prompt();

	while (1) {
		my $resp = $self->{llm}->call($system, \@messages, $model_name);
		# Tool-Calls verarbeiten (Multi-Turn ReAct)
		my $tool_calls = $resp->{choices}[0]{message}{tool_calls} || [];
		if (@$tool_calls) {
			for my $tc (@$tool_calls) {
				my $args = decode_json($tc->{function}{arguments} || "{}");
				my $result = $self->run_tool($tc->{function}{name}, $args);
				push @messages, {role => "tool", content => $result, tool_call_id => $tc->{id}};
				$self->_log("tool", "$tc->{function}{name}: $result");
			}
			next;  # nächster ReAct-Turn
		}

		# Final Answer
		my $answer = $resp->{choices}[0]{message}{content} || "Keine Antwort erhalten.";
		$self->_log("assistant", $answer);

		# Automatisch über Comm-Kanal senden
		$self->{comm}->send($self->{default_channel}, "FINAL: $answer");

		return $answer;
	}
}

# Hilfsmethoden
sub clear_history { $_[0]->{dbh}->do("DELETE FROM history") }
sub list_skills   { join ", ", @{$_[0]->{skills}} }

1;
#cs", "Query cost: approx. " . ($model_name ? "TBD" : "low"));
#        }
#
#        return $answer;
#    }
#}
#
# Hilfsmethoden
#sub clear_history { $_[0]->{dbh}->do("DELETE FROM history") }
#sub list_skills   { join ", ", @{$_[0]->{skills}} }

1;
