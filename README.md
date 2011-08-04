# myterm

### _(command line api for playing with iTerm)_

## About

`myterm` is a command line interface for customizing iTerm using AppleScript.  Its most useful feature is that it can throw up a big message in the background of your terminal tab to tell you clearly which tab it is.




## Usage

`myterm` attempts to be as self-documenting as possible.  Try `myterm -h` for help.

The most common use case for me personally is something like: 

    myterm bg --exec node server.js

which will display the string "node server.js" up in the background and then run that.




## Requirements

`myterm` needs ImageMagick and its `convert` executable to be in your path.

`myterm` needs some font file to use.  It has an installer that will try to grab the [Simple Life](http://www.dafont.com/simple-life.font) font by Michael Strobel.

Additionally it needs whatever its gem dependencie(s) are, which at the time of this writing are: rb-appscript, highline.




## Installation

`myterm` is a rubygem.  If you are installing it from a git checkout
(which at the time of this writing is the only way to install it):

    mkdir ~/src; cd ~/src
    git clone git@github.com:hipe/myterm.git; cd myterm
    gem build *.gemspec
    gem install *.gem


## Support

I want this to work for you.  Please contact me via email if it does not!




## Credits

`myterm` started life as an adaptation of Dmytro Shteflyuk's script that he used at Scribd as described  [here](http://kpumuk.info/mac-os-x/how-to-show-ssh-host-name-on-the-iterms-background/).  Thank you Dmytro!
