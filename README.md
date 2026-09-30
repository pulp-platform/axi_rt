# Slave Guard Module

Taming rogue subordinate units since 2024.

## Architecture

![Overview](doc/fig/overview.png)

### Features

* Timeout for each request channel towards a subordinate
    * per-ID or global
    * every new request adds budget to a counter
    * configurable

* Timeout for each response channel from a subordinate
    * per-ID or global
    * time between AW-B or W_last-B or AR-R_last

* Linter for each subordinate
    * reject non-requested responses
    * ensure lock-in
