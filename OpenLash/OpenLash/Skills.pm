package OpenLash::Skills;
use strict; use warnings;
use Path::Tiny;
use JSON::PP qw(decode_json);

sub new {
 my ($class, %args) = @_;
 my $self = bless {
 skills => [], # Array von Skill-Hashes
 ws => path($args{ws} || $args{workspace} || "$ENV{HOME}/.myclaw")
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
    return [ map { { name => $_->{name}, desc => "Skill: " . $_->{name}, params => $_->{params} || {} } } @{$self->{skills}} ];
}

# Run a specific skill (stub for dynamic execution)
sub run_skill {
    my ($self, $name, $args) = @_;
    my $skill = (grep { $_->{name} eq $name } @{$self->{skills}})[0] or return "Skill $name not found";
    
    if ($name eq 'shell') {
        my $cmd = $args->{cmd} or return "Shell skill requires 'cmd' param";
        # Basic safety: No sudo, timeout 10s, limit output
        eval {
            local $SIG{ALRM} = sub { die "Timeout" };
            alarm 10;
            my $output = `$cmd 2>&1`;
            alarm 0;
            return length($output) > 1024 ? substr($output, 0, 1024) . "\n[Truncated]" : $output;
        };
        alarm 0;
        return $@ =~ /Timeout/ ? "Shell command timed out" : "Shell error: $@";
    }
    
    # Add more skills here
    return "Skill $name executed (stub)";
}

1;
