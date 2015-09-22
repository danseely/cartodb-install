# This is the way we currently run cartodb persistently
# Place these items in /etc/crontab

PATH=/wherever/.rbenv/shims:/wherever/.rbenv/bin:/wherever/.rbenv/shims:/wherever/.rbenv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games

# Note that the last item must be uncommented
# for the development environment
# but is not necessary in prod

@reboot  username  bash /wherever/cdb-sql-api.sh > /dev/null 2>&1 &
@reboot  username  bash /wherever/cdb-windshaft.sh > /dev/null 2>&1 &
@reboot  username  bash /wherever/cdb-redis-server.sh > /dev/null 2>&1 &
@reboot  username  bash /wherever/cdb-resque.sh > /dev/null 2>&1 &

# being served by nginx in production
#@reboot         username  bash /wherever/cdb-cdb.sh > /dev/null 2>&1 &
