# find_admins

A very basic ruby script to find all admins in a github repository

## Usage

You need Ruby 2.4.3 installed - probably via rbenv - and a github API token.

To install dependencies:
```
$ gem install bundler
$ bundle
```

To run:
```
$ export GITHUB_TOKEN=adfasdfasdfgasdfasdf
$ ./find_admins.rb MyOrganisation my-repo-name
```

If you have rights to read the repo info, it should print all the repo admins -
github login, and full name if they've supplied it.

## License

        DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
                    Version 2, December 2004

 Copyright (C) 2014 Kornelis Sietsma <korny@sietsma.com>

 Everyone is permitted to copy and distribute verbatim or modified
 copies of this license document, and changing it is allowed as long
 as the name is changed.

            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

  0. You just DO WHAT THE FUCK YOU WANT TO.
