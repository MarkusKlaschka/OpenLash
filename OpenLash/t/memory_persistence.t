use Test::More tests => 3;
use Memory;

my $mem = Memory->new();
$mem->store("Test memory", { type => 'test' });
$mem->save_memories;

ok(-e $Memory::CONFIG->{memory_persist_file}, "Persistence file created");

my $mem2 = Memory->new();
$mem2->load_memories;
is(scalar @{$mem2->{memories}{working}}, 1, "Memory loaded correctly");

$mem2->store("", {});  # Invalid
is(scalar @{$mem2->{memories}{working}}, 1, "Invalid store rejected");
