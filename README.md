# lifesaver

Manage your Moonring filesaves.

## About

Moonring is "A dark-fantasy, turn-based, retro-fusion of classic turn-based RPGs
and roguelikes, all presented with a unique neon aesthetic." Made by
Fluttermind and released entirely free. Check it out on steam:
https://store.steampowered.com/app/2373630/Moonring/

This script automatically saves your current Moonring save files as '.tar.gz' in
a defined directory; and lets you select one of those tar archives to replace
the game's current save. This way you can rollback to any given point of your
run to have some fun, recover from a permadeath or make some regression testing.

I happened to be playing the game and wanted to contribute to its author by
reporting any bug I found. The game only let you have one save at a time, and I
wanted to be able to rollback and send the save files of any particular moment
of my run.

I also wanted to learn some Bash scripting, so ended doing this little
project. It really showed me the potentials, limitations and pitfalls of
Bash. Used Shellcheck as a linter to avoid common shell footguns and Bats as the
testing framework.

## Usage

> A Bash version of 4.0 or higher is needed to run 'lifesaver'. Use the testing
> suite to check the behavior if your Bash is not fully upgraded. See below.

To install it, clone the repository with `$ git clone
https://github.com/leonardosoteldo/lifesaver` and copy the 'lifesaver' file into
some directory defined in your shell `$PATH`, making it executable with `$ chmod
u+x lifesaver`.

### Examples

The most important uses are:

`$ lifesaver -f savefile.tar.gz -s ~/moonring/savedir/ -a ~/archive/directory/`

which will save current Moonring savefiles as
'~/archive/directory/savefile.tar.gz'.

After that, you'll want to recover archived savefile and use it as the game's
current savefile to reproduce your run. This can be made with:

`$ lifesaver -u ~/archive/directory/savefile.tar.gz -s ~/moonring/savedir/`

Using `$ lifesaver -h` you'll get this usage message:

```
Lifesaver: manage your Moonring savefiles.

 Syntax: lifesaver [OPTIONS]... [FILE]...

 options:
 -h          Display this [h]elp and exit.
 -F          [F]orce defined actions without asking for confirmation
             (this will overwrite any file without asking!)
 -a ARCHIVE  Define [a]rchive to which savefiles are added to.
 -s SAVE_DIR Define the Moonring [s]ave directory to be used.
 -p          [p]rint lifesaver's environmental variables values.
 -l          [l]ist all files in the archive directory and exit.
 -f FILE     Add current save [f]ile to the archive as FILE.tar.gz
 -u FILE     [u]pdate current Moonring savefile with FILE from the archive.
```

### Environment variables

The program behavior can be defined with the environment variables
`LIFESAVER_SAVE_DIR` and `LIFESAVE_ARCHIVE_DIR`. This will save you from having
to use the `-a ARCHIVE` and `-a SAVE_DIR` options every time you run it. You can
define them in your '.bashrc' file as:

```
export LIFESAVER_SAVE_DIR=/path/to/Moonring/savedir/
export LIFESAVER_ARCHIVE_DIR/path/to/your/savefiles/archive/
```

## Testing

If you want to check the script behavior you can run the automated tests. They
run pretty much every branch of the code. You'll need to install git submodules
(the consist of Bats libraries) with `$ git submodule init` and `$ git submodule
update`. Make sure you've made it executable with `chmod u+x ./test/run`. Then
execute the 'run' command with `$ ./test/run`.

Given my inclination and liking for testing code, I decided to use and learn a
testing framework for Bash. But after finishing this I realized that Bats,
although very powerful and useful tool, is overkill for little projects like
this one. It's a script of little more than 304 loc and Bats itself is about of
10MB of dependencies; which sounds just ridiculous...

Bats is a very nice framework with a lot of features, and I'm glad I got to
learn from it. I believe It has its uses when working with something large
written in Bash, but in the future I will probably just be rolling a small
testing script for this kind of small projects. Dylan Araps has one nice example
of this in the [Pure Bash Bible](https://github.com/dylanaraps/pure-bash-bible).
