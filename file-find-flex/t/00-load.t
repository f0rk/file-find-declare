use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;

lives_ok { use File::Find::Flex } 'File::Find::Flex loaded ok';
lives_ok { require File::Find::Flex } 'File::Find::Flex required ok';
