import os

from buildbot.master import BuildMaster
from twisted.application import service
from twisted.python.log import ILogObserver

basedir = os.environ.get('BUILDBOT_BASEDIR', '.')
rotateLength = int(os.environ.get("BUILDBOT_LOGROTATE_LENGTH", 5000))
maxRotatedFiles = int(os.environ.get("BUILDBOT_LOGROTATE_MAXFILES", 2))
configfile = 'master.cfg'

# Default umask for server
umask = None

# if this is a relocatable tac file, get the directory containing the TAC
if basedir == '.':
    basedir = os.path.abspath(os.path.dirname(__file__))

# note: this line is matched against to check that this is a buildmaster
# directory; do not edit it.
application = service.Application('buildmaster')

m = BuildMaster(basedir, configfile, umask)

# set different logger based on environment variable BUILDBOT_LOGDEST
# defaults to stdout for docker (NOT file!)
bb_logger = os.getenv("BUILDBOT_LOGDEST", "stdout").lower()

if bb_logger == "stdout" : # log to stdout (default in docker)
    import sys
    from twisted.python.log import FileLogObserver

    application.setComponent(ILogObserver, FileLogObserver(sys.stdout).emit)
    m.setServiceParent(application)

elif bb_logger == "syslog" : # log to syslog (default for virtualenv)
    from twisted.python.syslog import SyslogObserver

    application.setComponent(ILogObserver, SyslogObserver(prefix="buildmaster").emit)
    m.setServiceParent(application)

else : # elif bb_logger == "file" : # log to file (default in generated)
    from twisted.python.logfile import LogFile
    from twisted.python.log import FileLogObserver

    logfile = LogFile.fromFullPath(os.path.join(basedir, "twistd.log"), rotateLength=rotateLength, maxRotatedFiles=maxRotatedFiles)

    application.setComponent(ILogObserver, FileLogObserver(logfile).emit)
    m.setServiceParent(application)
    m.log_rotation.rotateLength = rotateLength
    m.log_rotation.maxRotatedFiles = maxRotatedFiles

