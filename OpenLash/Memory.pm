package OpenLash::Memory;
use strict; use warnings;
use Path::Tiny;
use DBI;
use JSON::PP qw(encode_json);

sub new {
	my ($class, %args) = @_;
	my $self = bless { ws => path($args{workspace} || "$ENV{HOME}/.myclaw") }, $class;
	$self->_init_db;
	return $self;
}

sub _init_db {
	my $self = shift;
	$self->{dbh} = DBI->connect("dbi:SQLite:dbname=" . $self->{ws}->child("memory.db"), "", "", {RaiseError => 1});
	$self->{dbh}->do("
		CREATE TABLE IF NOT EXISTS memory (
			id		  INTEGER PRIMARY KEY,
			session_id  TEXT,
			timestamp   DATETIME DEFAULT CURRENT_TIMESTAMP,
			key		 TEXT,
			value	   TEXT,
			keywords	TEXT,		  -- JSON-Array
			importance  INTEGER DEFAULT 5,
			context	 TEXT
		)
	");
}

# Speichern mit Metadaten
sub store {
	my ($self, $value, %meta) = @_;
	my $kw = encode_json($meta{keywords} || []);
	$self->{dbh}->do("INSERT INTO memory (session_id, key, value, keywords, importance, context) VALUES (?,?,?,?,?,?)",
		undef, $meta{session_id}, $meta{key}, $value, $kw, $meta{importance}||5, $meta{context});
}

# Suche nach Keywords
sub recall_keywords {
	my ($self, @keywords) = @_;
	my $like = "%" . join("%", @keywords) . "%";
	return $self->{dbh}->selectall_arrayref("SELECT * FROM memory WHERE keywords LIKE ? ORDER BY importance DESC, timestamp DESC LIMIT 20", {Slice=>{}}, $like);
}

# Session-spezifisch
sub recall_session {
	my ($self, $session_id, $limit) = @_;
	return $self->{dbh}->selectall_arrayref("SELECT * FROM memory WHERE session_id = ? ORDER BY timestamp DESC LIMIT ?", {Slice=>{}}, $session_id, $limit||30);
}

# Zeit-basiert (letzte X Minuten/Stunden)
sub recall_recent {
	my ($self, $minutes) = @_;
	return $self->{dbh}->selectall_arrayref("SELECT * FROM memory WHERE timestamp >= datetime('now', '-$minutes minutes') ORDER BY timestamp DESC", {Slice=>{}});
}

# Intelligente Suche (Keywords + Session + Zeit)
sub get_relevant {
	my ($self, $query, $session_id) = @_;
	my @kw = split /\s+/, $query;
	my $rows = $self->recall_keywords(@kw);
	push @$rows, @{$self->recall_session($session_id)} if $session_id;
	return $rows;
}

# Für den Prompt
sub get_prompt_text {
	my $self = shift;
	my $rows = $self->recall_recent(60);  # letzte Stunde
	return "=== Langzeitgedächtnis ===\n" . join("\n", map { "[$_->{timestamp}] $_->{value}" } @$rows);
}

sub clear { $_[0]->{dbh}->do("DELETE FROM memory") }

1;
