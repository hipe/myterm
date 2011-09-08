# myterm

### _(command line api for playing with iTerm)_

## About

`myterm` is a command line interface for customizing iTerm using AppleScript.  Its most useful feature is that it can throw up a big message in the background of your terminal tab to tell you clearly which tab it is.




## Usage

`myterm` attempts to be as self-documenting as possible.  Try `myterm -h` for help.

The most common use case for me personally is usually something like: 

    myterm bg ohai

where "ohai" is some label that I want to appear in the background of the iTerm window.

More ambitiously, I might do:

    myterm bg --exec node server.js

which will display the string "node server.js" up in the background and then run that.




## Requirements

`myterm` needs ImageMagick and its `convert` executable to be in your path.

Installing ImageMagick on your mac is "easy" with macports, provided that you don't run into hiccups.  (But be prepared for it to take something like5 minutes.)

`myterm` needs some font file to use.  It has an installer that will try to grab the [Simple Life](http://www.dafont.com/simple-life.font) font by Michael Strobel.

Additionally it needs whatever its gem dependencie(s) are (which at the time of this writing are: rb-appscript, highline, rmagick).  Installing the myterm ruby gem should install these dependencies.  If you are developing myterm you could also install them with "bundle install".





## Installation

`myterm` is a rubygem.  If you are installing it from a git checkout
(which at the time of this writing is the only way to install it):

    mkdir ~/src; cd ~/src
    git clone git@github.com:hipe/myterm.git; cd myterm
    gem build myterm.gemspec
    gem install myterm-VERSION.gem # where VERSION is whatever version was built.



## Support

I want this to work for you.  Please contact me via email if it does not!




## Credits

`myterm` started life as an adaptation of Dmytro Shteflyuk's script that he used at Scribd as described  [here](http://kpumuk.info/mac-os-x/how-to-show-ssh-host-name-on-the-iterms-background/).  Thank you Dmytro!
