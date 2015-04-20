# Copyright (c) 2013-2015 Snowplow Analytics Ltd. All rights reserved.
#
# This program is licensed to you under the Apache License Version 2.0,
# and you may not use this file except in compliance with the Apache License Version 2.0.
# You may obtain a copy of the Apache License Version 2.0 at http://www.apache.org/licenses/LICENSE-2.0.
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the Apache License Version 2.0 is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the Apache License Version 2.0 for the specific language governing permissions and limitations there under.
#
# Version: 3-0-0
#
# Authors: Yali Sassoon, Christophe Bogaert
# Copyright: Copyright (c) 2013-2015 Snowplow Analytics Ltd
# License: Apache License Version 2.0

- view: sessions_source
  derived_table:
    sql: |
      SELECT
        *
      FROM (
        SELECT -- Select campaign and referer data from the earliest row (using dvce_tstamp)
          
          a.domain_userid,
          a.domain_sessionidx,
          
          a.mkt_source,
          a.mkt_medium,
          a.mkt_term,
          a.mkt_content,
          a.mkt_campaign,
          
          a.refr_source,
          a.refr_medium,
          a.refr_term,
          a.refr_urlhost,
          a.refr_urlpath,
          
          RANK() OVER (PARTITION BY a.domain_userid, a.domain_sessionidx ORDER BY a.mkt_source, a.mkt_medium,
            a.mkt_term, a.mkt_content, a.mkt_campaign, a.refr_source, a.refr_medium, a.refr_term,
            a.refr_urlhost, a.refr_urlpath) AS rank
        
        FROM ${events.SQL_TABLE_NAME} AS a
        INNER JOIN ${sessions_basic.SQL_TABLE_NAME} AS b
          ON  a.domain_userid = b.domain_userid
          AND a.domain_sessionidx = b.domain_sessionidx
          AND a.dvce_tstamp = b.dvce_min_tstamp
        WHERE a.refr_medium != 'internal' -- Not an internal referer
          AND (
            NOT(a.refr_medium IS NULL OR a.refr_medium = '') OR
            NOT (
              (a.mkt_campaign IS NULL AND a.mkt_content IS NULL AND a.mkt_medium IS NULL AND a.mkt_source IS NULL AND a.mkt_term IS NULL) OR
              (a.mkt_campaign = '' AND a.mkt_content = '' AND a.mkt_medium = '' AND a.mkt_source = '' AND a.mkt_term = '')
            )
          )
        GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12 -- Aggregate identital rows (that happen to have the same dvce_tstamp)
      )
      WHERE rank = 1 -- If there are different rows with the same dvce_tstamp, rank and pick the first row
    
    sql_trigger_value: SELECT COUNT(*) FROM ${sessions_first_page.SQL_TABLE_NAME} # Generate this table after sessions_first_page
    distkey: domain_userid
    sortkeys: [domain_userid, domain_sessionidx]