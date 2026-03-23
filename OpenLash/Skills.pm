package OpenLash::Skills;
use strict; use warnings;
use Path::Tiny;
use JSON::PP qw(decode_json);

sub new {
	my ($class, %args) = @_;
	my $self = bless {
		skills => [],					 # Array von Skill-Hashes
		ws	 => path($args{workspace} || "$ENV{HOME}/.myclaw")
	}, $class;
	return $self;
}

# Skill hinzufügen (Name + optional Params)
sub add_skill {
	my ($self, %s) = @_;
	push @{$self->{skills}}, \%s;
}

# Skills aus JSON laden (Beispiel: [{"name":"shell","params":{...}}])
sub load_config {
	my ($self, $file) = @_;
	my $data = decode_json(path($file)->slurp);
	$self->add_skill(%$_) for @$data;
}

# Alle SKILL.md-Dateien für den Prompt
sub get_prompt_text {
	my $self = shift;
	my $p = "";
	for my $s (@{$self->{skills}}) {
		my $file = $self->{ws}->child("skills/$s->{name}/SKILL.md");
		$p .= $file->slurp . "\n\n" if $file->exists;
	}
	return $p;
}

# Tool-Schemas für das LLM
sub get_tool_definitions {
	my $self = shift;
	return [ map { { name => $_->{name}, desc => "Skill $_->{name}", params => $_->{params} || {} } } @{$self->{skills}} ];
}

1;
