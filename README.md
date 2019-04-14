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

If you have write/push access the repo, it should print all the repo admins - github login, and full name if they've supplied it.

If you only have read access, it will still attempt to find some admins by iterating over the list of public teams and seeing if any of these teams are administrators on the repo in question, but this method is less accurate than the first.

## License
Written in 2018 by Kornelis Sietsma korny@sietsma.com

To the extent possible under law, the author(s) have dedicated all copyright and related and neighboring rights to this software to the public domain worldwide. This software is distributed without any warranty.
You should have received a copy of the CC0 Public Domain Dedication along with this software. If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.
