# rsyslog

The files in this directory can serve as template for using Rsyslog as the
first agent in a Syslog event collection pipeline. In the long run, it is
planned to replace Rsyslog by Vector but for now, Vector is missing important
features which is why Rsyslog and Vector are used together.

This directory allows testing Rsyslog config in isolation.

`rsyslog.d/` can be deployed to production. `rsyslog.conf` is modified to run
in isolation and should not be deployed to production.
