# replace-ssh-key
Simplifies the replacement of SSH keys on all servers the current machine has
used those keys on.

The history of where you've previosuly connected via SSH is obtained by naively
extracting the information from `$HOME/.ssh/known_hosts`

The replacement procedure is as follows:

1. Extract all hosts from the known_hosts file.
2. For each host try to connect to it using the old key (the one to be replaced).
3. If connection was successful, then replace the key's record in
    `~/.ssh/authorized_keys` on the remote host, with the contents of the new
   public key.

_Note_: Before running this for all machines, ensure that it works as expected
by supplying the `--dry-run` flag. The script will then run in simulation mode,
printing out every command instead of actually executing it. When you're
confident the behavior is as you expect, then you can run it for your entire
fleed of machines.

## Usage
```
Usage: replace-ssh-key.rb [options] [OLD_KEY [NEW_KEY]]

Swaps an old SSH key for a new one on all known and connectable hosts/servers
where the OLD_KEY allows login. The user used for login will be either the
current user or whatever user mapping results from the user's machine or per-
user SSH client configuration (e.g. `$HOME/.ssh/config`)

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
    -v, --verbose                    Show verbose output
    -d, --dry-run                    Simulate the key replacement process
```

## Examples

### List servers you've previously connected to
The servers stored in ~/.ssh/known_hosts, which will be checked during
replacement if they have your old key in there.
```
./replace-ssh-key.rb --list
```

### Check what servers are still alive
To help gauging what fraction of servers you've previosly visited are still up.
```
./replace-ssh-key.rb ~/.ssh/id_rsa.old --connect
```

### Replace an old key with a new key
```
./replace-ssh-key.rb ~/.ssh/id_rsa.old ~/.ssh/id_rsa --replace
```
This replaces the old key with the new on all servers that the old key can
login to.