#!/usr/bin/env python
#
# Workload Automation v2 for LAVA
#
# Copyright (C) 2014, Linaro Limited.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# Author: Milosz Wasilewski <milosz.wasilewski@linaro.org>
#

import os
import sys
import sqlite3
from optparse import OptionParser

sys.path.insert(0, '../lib/')
import py_test_lib  # nopep8

RESULT_FILE = os.getenv("RESULT_FILE", "./output/result.txt")

ENERGY = 'energy'
TIME = 'time'

results_prepared_statement = """
SELECT spec_id, metric, mean_value(sum(value), count(value)) as mean_value, units, lower_is_better
FROM results
GROUP BY spec_id, metric;
"""

consolidated_prepared_statement = """
SELECT
    spec_id,
    metric,
    relative_value(
        mean_value(sum(value), count(value)),
        (SELECT
            mean_value(sum(value), count(value)) AS ref_mean_value
        FROM results AS ref_results
        WHERE spec_id LIKE ?
            AND metric = ?
            AND workload = ?
        GROUP BY spec_id, metric),
        lower_is_better) as relative_value
FROM results
WHERE metric = ?
AND workload = ?
GROUP BY spec_id, metric;
"""

energy_prepared_statement = """
SELECT spec_id, sum(mean_value) as mean_value
    FROM
        (SELECT spec_id, mean_value(sum(value), count(value)) as mean_value
        FROM results
        WHERE metric IN (%s)
        GROUP BY spec_id, metric)
    GROUP BY spec_id;
"""


def mean_value(total, iterations):
    return float(total) / float(iterations)


def relative_value(value, reference, lower_is_better):
    if lower_is_better:
        return 100 * (float(reference) / float(value))
    return 100 * (float(value) / float(reference))

if __name__ == '__main__':

    usage = "usage: %prog [OPTIONS]"
    parser = OptionParser(usage=usage)
    parser.add_option("-l", "--consolidation-label-list", dest="consolidation_label_list",
                      default="Mean Latency",
                      help='''
                      Measurement label which is used for consolidating
                      relative results. For example "Mean Latency",
                      ''')
    parser.add_option("-e", "--energy-label-list", dest="energy_label_list",
                      default="arm,vexpress-energy A15 Jcore;arm,vexpress-energy A7 Jcore",
                      help='''
                      List of labels which will be summarizer for power
                      comparison. For example 'arm,vexpress-energy A15
                      Jcore;arm,vexpress-energy A7 Jcore'. Note execution_time
                      is always used for calculating power from energy numbers
                      ''')
    parser.add_option("-w", "--workload", dest="consolidation_workload",
                      help="Workflow for which consolidation is performed. For example 'linpack'",
                      default="linpack")
    parser.add_option("-m", "--mode", dest="reference_mode",
                      help="Reference mode which is used as 100% for relative measurement. Default: a15",
                      default="a15")
    parser.add_option("-p", "--path", dest="global_data_path",
                      help="Path where results database is located",
                      default="./output/wa/results.sqlite")

    (options, args) = parser.parse_args()

    print("consolidation label list: %s" % options.consolidation_label_list)
    print("energy label list: %s" % options.energy_label_list)
    print("consolidation workload: %s" % options.consolidation_workload)
    print("reference mode: %s" % options.reference_mode)
    print("path: %s" % options.global_data_path)

    ref_mode = "%%%s%%" % options.reference_mode
    consolidation_label_list = options.consolidation_label_list.split(";")
    energy_label_list = options.energy_label_list.split(";")

    print("opening %s" % (options.global_data_path))
    conn = sqlite3.connect(options.global_data_path)
    conn.row_factory = sqlite3.Row
    conn.create_function("mean_value", 2, mean_value)
    conn.create_function("relative_value", 3, relative_value)
    results_cursor = conn.cursor()
    for row in results_cursor.execute(results_prepared_statement):
        result = "%s_%s pass %s %s" % (
            row['spec_id'],
            row['metric'].replace(" ", "_").replace(",", "_"),
            row['mean_value'],
            row['units'])
        py_test_lib.add_result(RESULT_FILE, result)
    results_cursor.close()

    consolidated_cursor = conn.cursor()
    for label in consolidation_label_list:
        for row in consolidated_cursor.execute(
            consolidated_prepared_statement,
            (ref_mode,
                label,
                options.consolidation_workload,
                label,
                options.consolidation_workload)):
            result = "Relative_%s_%s pass %s %s" % (
                row['spec_id'],
                row['metric'].replace(" ", "_").replace(",", "_"),
                row['relative_value'])
            py_test_lib.add_result(RESULT_FILE, result)
    consolidated_cursor.close()

    energy_cursor = conn.cursor()
    energy_dict = {}
    ref_energy = None
    ref_time = None
    for row in energy_cursor.execute(energy_prepared_statement % ','.join('?' * len(energy_label_list)), energy_label_list):
        energy_dict[row['spec_id']] = {ENERGY: row['mean_value']}
        if options.reference_mode in row['spec_id']:
            ref_energy = row['mean_value']
    if energy_dict:
        for row in energy_cursor.execute(energy_prepared_statement % ('?'), ("execution_time",)):
            energy_dict[row['spec_id']].update({TIME: row['mean_value']})
            if options.reference_mode in row['spec_id']:
                ref_time = row['mean_value']
    energy_cursor.close()
    if ref_energy and ref_time:
        ref_power = float(ref_energy) / float(ref_time)
        for key, value in energy_dict.iteritems():
            result = "Relative_power_%s pass %s %s" % (key, 100 * ((value[ENERGY] / value[TIME]) / ref_power))
            py_test_lib.add_result(RESULT_FILE, result)
