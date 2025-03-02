# reference:
#   https://github.com/buildbot/buildbot/blob/master/worker/docker/buildbot.tac

import fnmatch
import os

from buildbot_worker.bot import Worker
from twisted.application import service
from twisted.python.log import ILogObserver

basedir = os.environ.get('BUILDBOT_BASEDIR', '.')
rotateLength = int(os.environ.get("BUILDBOT_LOGROTATE_LENGTH", 5000))
maxRotatedFiles = int(os.environ.get("BUILDBOT_LOGROTATE_MAXFILES", 2))

buildmaster_host = os.environ.get("BUILDBOT_MASTERADDRESS", 'localhost')
port = int(os.environ.get("BUILDBOT_MASTERPORT", 9989))
workername = os.environ.get("BUILDBOT_WORKERNAME", 'docker')
passwd = os.environ.get("BUILDBOT_WORKERPASS", 'insecurebydefault')

# delete the password from the environ so that it is not leaked in the log
blacklist = os.environ.get("BUILDBOT_WORKER_ENVIRONMENT_BLACKLIST", "BUILDBOT_WORKERPASS").split()
for name in list(os.environ.keys()):
    for toremove in blacklist:
        if fnmatch.fnmatch(name, toremove):
            del os.environ[name]

allow_shutdown = None
delete_leftover_dirs = int(os.environ.get("BUILDBOT_WORKER_DELETE_LEFTOVER_DIRS", 0))
keepalive = int(os.environ.get("BUILDBOT_WORKER_KEEPALIVE", 30))
maxdelay = int(os.environ.get("BUILDBOT_WORKER_MAXRETRIES", 60))
maxretries = int(os.environ.get("BUILDBOT_WORKER_MAXRETRIES", 5))
numcpus = None
protocol = os.environ.get("BUILDBOT_PROTOCOL", 'pb')
proxy_connection_string = os.environ.get("BUILDBOT_PROXY_CONNECTION_STRING", None)
umask = 0o022
use_tls = int(os.environ.get("BUILDBOT_WORKER_USETLS", 0))

# if this is a relocatable tac file, get the directory containing the TAC
if basedir == '.':
    basedir = os.path.abspath(os.path.dirname(__file__))

# note: this line is matched against to check that this is a worker
# directory; do not edit it.
application = service.Application('buildbot-worker')

s = Worker(buildmaster_host, port, workername, passwd, basedir,
           keepalive, umask=umask, maxdelay=maxdelay,
           numcpus=numcpus, allow_shutdown=allow_shutdown,
           maxRetries=maxretries, protocol=protocol, useTls=use_tls,
           delete_leftover_dirs=delete_leftover_dirs,
           proxy_connection_string=proxy_connection_string)

# set different logger based on environment variable BUILDBOT_LOGDEST
# defaults to stdout for docker (NOT file!)
bb_logger = os.getenv("BUILDBOT_LOGDEST", "stdout").lower()

if bb_logger == "stdout" : # log to stdout (default in docker)
    import sys
    from twisted.python.log import FileLogObserver

    application.setComponent(ILogObserver, FileLogObserver(sys.stdout).emit)
    s.setServiceParent(application)

elif bb_logger == "syslog" : # log to syslog (default for virtualenv)
    from twisted.python.syslog import SyslogObserver

    application.setComponent(ILogObserver, SyslogObserver(prefix="buildworker").emit)
    s.setServiceParent(application)

else : # elif bb_logger == "file" : # log to file (default in generated)
    from twisted.python.logfile import LogFile
    from twisted.python.log import FileLogObserver

    logfile = LogFile.fromFullPath(os.path.join(basedir, "twistd.log"), rotateLength=rotateLength, maxRotatedFiles=maxRotatedFiles)

    application.setComponent(ILogObserver, FileLogObserver(logfile).emit)
    s.setServiceParent(application)
    s.log_rotation.rotateLength = rotateLength
    s.log_rotation.maxRotatedFiles = maxRotatedFiles
