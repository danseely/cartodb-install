I've had some trouble getting the whole stack up & running:
  - automatically
  - in the background
  - on boot

Here's the process.

---

First, I tried an upstart script.

---

Next was putting all the commands in a bash script, and running that on boot via the `crontab`. Here was the first script:

```bash
#!/bin/bash

node /wherever/CartoDB-SQL-API/app.js development &
sleep 10

node /wherever/Windshaft/app.js development &
sleep 10

cd /wherever/cartodb
redis-server &
sleep 10

bundle exec script/resque &
sleep 20

bundle exec rails s -p 3000 &
```

That didn't work, not sure why.

---

Next, I tried one script for each service, for example `cdb-sql-api.sh` looked like this:

```bash
#!/bin/bash

cd /wherever/CartoDB-SQL-API
node app.js development
```

That seemed to start the services, but resque & redis weren't running properly as dataset imports wouldn't work.

---

Third try with the bash scripts was to include a bit in the `crontab` call to send the output to a file, and background the task -- as far as I can tell, `2>&1` redirects terminal & error output to logfile and `&` backgrounds task; to bring to foreground for quitting: `fg`.

I changed the script calls in the crontab to:

```bash
@reboot         dseely  bash /wherever/cdb-sql-api.sh > /wherever/devlog.txt 2>&1 &
@reboot         dseely  bash /wherever/cdb-windshaft.sh > /wherever/devlog.txt 2>&1 &
@reboot         dseely  bash /wherever/cdb-redis-server.sh > /wherever/devlog.txt 2>&1 &
@reboot         dseely  bash /wherever/cdb-resque.sh > /wherever/devlog.txt 2>&1 &
@reboot         dseely  bash /wherever/cdb-cdb.sh > /wherever/devlog.txt 2>&1 &
```

So far, this method has worked across multiple system reboots.

---
