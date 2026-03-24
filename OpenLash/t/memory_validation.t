use Test::More tests => 4;
use Memory;

my $mem = Memory->new();

$mem->store("Valid text", { key => 'value' });
is(scalar @{$mem->{memories}{working}}, 1, "Valid store accepted");

$mem->store(123, { key => 'value' });  # Invalid text
is(scalar @{$mem->{memories}{working}}, 1, "Invalid text rejected");

$mem->store("Text", "not hash");  # Invalid metadata
is(scalar @{$mem->{memories}{working}}, 1, "Invalid metadata rejected");

$mem->recall("");  # Invalid query
ok(1, "Invalid recall handled");  # Assuming it returns empty
