#!/usr/bin/perl
{
package MyWebServer;
use HiPi::BCM2835;
use HiPi::BCM2835::I2C;
use HiPi::Utils;

my $register = 7;
HiPi::BCM2835->bcm2835_init();
my $dev = HiPi::BCM2835::I2C->new( address => 0x5a );

use HTTP::Server::Simple::CGI;
use base qw(HTTP::Server::Simple::CGI);

my %dispatch = (
    '/mlx' => \&resp_mlx,
);

sub handle_request {
    my $self = shift;
    my $cgi  = shift;
  
    my $path = $cgi->path_info();
    my $handler = $dispatch{$path};

    if (ref($handler) eq "CODE") {
        print "HTTP/1.0 200 OK\r\n";
        $handler->($cgi);
        
    } else {
        print "HTTP/1.0 404 Not found\r\n";
        print $cgi->header,
              $cgi->start_html('Not found'),
              $cgi->h1('Not found'),
              $cgi->end_html;
    }
}

sub resp_mlx {
    my $cgi  = shift;   # CGI.pm object
    return if !ref $cgi;

    my (@reg_val) = (255, 255);
    while(@reg_val[1] >= 127)
    {
    eval {
         @reg_val = $dev->i2c_read_register_rs($register, 0x02);
         };
    };
    my ($temp_c) = ((@reg_val[1] * 256 + @reg_val[0]) / 50) - 273.15 ;
    
    print $cgi->header;
    print "$temp_c";
}

} 

# start the server on port 8080
my $pid = MyWebServer->new(8080)->background();
print "Use 'kill $pid' to stop server.\n";

