# replace-ssh-key
Simplifies the replacement of SSH keys on all servers the current machine has
used those keys on.

The history of where you've previously connected via SSH is obtained by naively
extracting the information from `$HOME/.ssh/known_hosts`

The replacement procedure is as follows:

1. Extract all hosts from the known_hosts file.
2. For each host try to connect to it using the old key (the one to be replaced).
3. If connection was successful, then replace the key's record in
    `~/.ssh/authorized_keys` on the remote host, with the contents of the new
   public key.

_Note_: Before running this for all machines, ensure that it works as expected
by supplying the `--dry-run` flag. The script will then run in simulation mode,
printing out every command instead of actually executing them. When you're
confident the behavior is as you expect, then you can run it for your entire
fleet of machines.

## Usage
```
Usage: replace-ssh-key.rb [options] [OLD_KEY [NEW_KEY]]

Swaps an old SSH key for a new one on all known and connectable hosts/servers
where the OLD_KEY allows login. The user used for login will be either the
current user or whatever user mapping results from the user's machine or per-
user SSH client configuration (e.g. $HOME/.ssh/config)

Arguments:
  OLD_KEY and NEW_KEY are both paths to the respective keys.

Options:
    -l, --list                       List the servers that are going to be
                                     tried.
    -c, --connect                    Check which of the servers can be logged
                                     into using the old key.
    -t, --timeout=5                  Treat the connection attempt as failed
                                     unless connection was established within
                                     these many seconds.
    -R, --replace                    Perform the actual key replacement action.
    -f, --hosts=~/.ssh/known_hosts   File that contains a space or line
                                     delimited list of hostnames / IP addresses
                                     to process.
    -v, --verbose                    Show verbose output
    -d, --dry-run                    Simulate the key replacement process
```

## Examples

### List servers you've previously connected to
The servers stored in ~/.ssh/known_hosts will be processed during replacement.
```
./replace-ssh-key.rb --list
```

### Check what servers are still alive
To help gauge what servers you've previously visited are still up.
```
./replace-ssh-key.rb ~/.ssh/id_rsa.old --connect
```

### Replace an old key with a new key
```
./replace-ssh-key.rb ~/.ssh/id_rsa.old ~/.ssh/id_rsa --replace
```
This replaces the old key with the new on all servers that the old key can
login to.

### Replace a key using a custom list of hosts
```
./replace-ssh-key.rb ~/.ssh/id_rsa.old ~/.ssh/id_rsa -f my-hosts-file --replace
```
Same as the previous example, but will replace the keys for the hosts listed
in `my-host-file`, instead of using `~/.ssh/known_hosts` as the source

### Run the script in a Docker container
```
./run-in-docker.sh --list
```
The docker option may be suitable for those who don't like Ruby and
consequently don't have it installed on their system. Everyone has docker
though (or ought to :)

The script mounts the docker host's current working directory as the working
directory in the container. It also mounts the user's `~/.ssh` directory into the
container user's ~/.ssh directory, so that everything matches up, as if the
script had been launched from the host machine.

## Assumptions
The following assumptions have been made, and need to be true in order for the
script to work as intended:

1. The machine that runs the script has openssh installed.
2. There is a public key in the same directory as the private key for both the
   old and new keys. E.g if the private key is named `id_rsa`, then it is
   expected that there is a file named `id_rsa.pub` in the same directory.
3. Hashed hostnames are not being used (`HashKnownHosts no` in ssh config)
   Without it there is no way to automatically figure out what machines the
   script need to swap the keys for. If the user "suffers" from hashed
   hostnames in the known_hosts file, then they have an out through the
   --hosts option.

The reason for the second assumption is that some users (me included) have a
habit of adding comments to the public key, so we know what keys are installed,
at a glance, on various machines. When using ssh-keygen to "generate" an public
key on the fly, no comments are provided as the "private key" doesn't contain
any such information.

The first assumption should be easy enough to satisfy. Most all linux systems
use openssh, OSX has what looks like it and even windows has it readily
available via Cygwin.

For PuTTY user I'd recommend installing Cygwin's SSH and then export/transform
the _old_ and _new_ keys you use in PuTTY to the OpenSSH format. After that
you'll be able to use this script for replacing the keys, without having to
abandon the use of Simon Tatham's awesome SSH client.
