#
#    SPDX-License-Identifier: Apache-2.0
#
#!/bin/sh
/bin/sh wait-for ${PGHOST}:${PGPORT} -t 500 -- sleep 1
psql -h ${PGHOST} -d postgres -U ${PGUSER} -W ${PGPASSWORD} -f app/persistence/postgreSQL/db/explorerpg.sql
psql -h ${PGHOST} -d postgres -U ${PGUSER} -W ${PGPASSWORD} -f app/persistence/postgreSQL/db/updatepg.sql
node main.js
