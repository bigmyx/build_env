#!/usr/bin/env python
'''
Set a random hostname to avoid DNS/DHCP issues. Called by @reboot cron job.
'''
import os
COMMANDS = [
    "/usr/sbin/scutil --set HostName %s.example.com",
    "/usr/sbin/scutil --set LocalHostName %s",
    "/usr/sbin/scutil --set ComputerName %s",
]

if __name__ == "__main__":
    hostname = "osx-%s" % os.urandom(4).encode('hex')
    for c in COMMANDS:
        c = c % hostname
        result = os.system(c)
        os.system('echo "osx_set_random_hostname: %s -> %s" | /usr/bin/logger' % (c, result))
