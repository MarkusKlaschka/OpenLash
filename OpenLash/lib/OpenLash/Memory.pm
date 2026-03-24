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
            id          INTEGER PRIMARY KEY,
            session_id  TEXT,
            timestamp   DATETIME DEFAULT CURRENT_TIMESTAMP,
            key         TEXT,
            value       TEXT,
            keywords    TEXT,           -- JSON array
            importance  INTEGER DEFAULT 5,
            context     TEXT,
            active      INTEGER DEFAULT 0
        )
    ");
    # Index for faster keyword search
    $self->{dbh}->do("CREATE INDEX IF NOT EXISTS idx_keywords ON memory(keywords)");
    $self->{dbh}->do("CREATE INDEX IF NOT EXISTS idx_importance ON memory(importance DESC, timestamp DESC)");
    $self->{dbh}->do("CREATE INDEX IF NOT EXISTS idx_active ON memory(active)");
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

sub export {
    my ($self, $file) = @_;
    my $rows = $self->{dbh}->selectall_arrayref("SELECT * FROM memory ORDER BY timestamp", {Slice => {}});
    path($file)->spew(encode_json($rows));
    return scalar @$rows;
}

sub import {
    my ($self, $file) = @_;
    return unless -e $file;
    my $data = decode_json(path($file)->slurp);
    $self->store_batch($_) for @$data;
    return scalar @$data;
}

sub clear { $_[0]->{dbh}->do("DELETE FROM memory") }


sub nm_store {
 my ($self, $name, $text, $active) = @_;
 $active //= 0;
 $self->store($text, key => $name, active => $active);
 return "Stored named memory '$name' (active: $active)";
}

sub nm_list {
 my ($self, %opts) = @_;
 my $where = $opts{active} ? "WHERE active = 1" : ($opts{all} ? "" : "WHERE active = 1");
 my $rows = $self->{dbh}->selectall_arrayref("SELECT key, active FROM memory $where GROUP BY key", {Slice => {}});
 return join("\n", map { "$_->{key} (active: $_->{active})" } @$rows) || "No named memories";
}

sub nm_toggle {
 my ($self, $name, $active) = @_;
 return "Name required" unless $name;
 $self->{dbh}->do("UPDATE memory SET active = ? WHERE key = ?", undef, $active, $name);
 return "Toggled '$name' to active: $active";
}

sub get_active_named {
 my $self = shift;
 my $rows = $self->{dbh}->selectall_arrayref("SELECT value FROM memory WHERE active = 1 ORDER BY timestamp DESC", {Slice => {}});
 return join("\n", map { $_->{value} } @$rows) || "";
}

1;
