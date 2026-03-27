package OpenLash::Tasks;
use strict; use warnings;
use Path::Tiny;
use lib path(__FILE__)->parent->parent->stringify;
use Path::Tiny;
use JSON::PP qw(decode_json);

sub new {
	my ($class, %args) = @_;
	bless { tasks => [], ws => path($args{workspace} || "$ENV{HOME}/.myclaw") }, $class;
}

sub add_task {
	my ($self, %task) = @_;
	push @{$self->{tasks}}, { %task, status => "pending", id => time() . rand() };
}

sub load_config {
	my ($self, $file) = @_;
	my $data = decode_json(path($file)->slurp);
	$self->add_task(%$_) for @$data;
}

sub get_pending { grep { $_->{status} eq "pending" } @{$_[0]->{tasks}} }

sub mark_done {
	my ($self, $id) = @_;
	$_->{status} = "done" for grep { $_->{id} eq $id } @{$_[0]->{tasks}};
}

sub get_prompt_text {
	my $self = shift;
	return "Offene Tasks:\n" . join("\n", map { "- $_->{title} (prio $_->{priority})" } $self->get_pending());
}

1;
