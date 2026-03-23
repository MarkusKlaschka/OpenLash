package OpenLash::Lessons;
use strict; use warnings;
use Path::Tiny;
use JSON::PP;

sub new {
	my ($class, %args) = @_;
	bless { lessons => [], ws => path($args{workspace} || "$ENV{HOME}/.myclaw") }, $class;
}

sub add_lesson {
	my ($self, %lesson) = @_;
	push @{$self->{lessons}}, \%lesson;
}

sub load_config {
	my ($self, $file) = @_;
	my $data = decode_json(path($file)->slurp);
	$self->add_lesson(%$_) for @$data;
}

sub get_relevant {
	my ($self, $topic) = @_;
	return grep { $_->{topic} =~ /$topic/i } @{$self->{lessons}};
}

sub get_prompt_text {
	my $self = shift;
	return join("\n\n", map { "Lesson: $_->{topic}\n$_->{text}" } @{$self->{lessons}});
}

1;
