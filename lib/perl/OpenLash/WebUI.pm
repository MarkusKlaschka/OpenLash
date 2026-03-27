package OpenLash::WebUI;
use strict;
use warnings;
use Template;

sub new {
    my () = @_;
    my  = bless {
        template => Template->new({
            INCLUDE_PATH => /root/OpenLash/webserver/tpl,
        }),
    }, ;
    return ;
}

sub render {
    my (, , ) = @_;
    my ;
    ->{template}->process(, , $output) or die ->{template}->error();
    return ;
}

1;
