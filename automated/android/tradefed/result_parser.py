import collections
import logging
import os
import re
import sys
import xml.etree.ElementTree as ET

sys.path.insert(0, '../../lib/')
import py_test_lib  # nopep8


class TradefedResultParser:
    AGGREGATED = "aggregated"
    ATOMIC = "atomic"

    def __init__(self, result_output_file):
        self.result_output_file = result_output_file
        self.logger = logging.getLogger()
        self.failures_to_print = 0
        self.results_format = TradefedResultParser.AGGREGATED
        self.test_result_file_name = 'test_result.xml'

    def parse_recursively(self, result_dir):
        if not os.path.exists(result_dir) or not os.path.isdir(result_dir):
            return False
        for root, dirs, files in os.walk(result_dir):
            for name in files:
                if name != self.test_result_file_name:
                    continue
                if not self.parse(os.path.join(root, name)):
                    return False
        return True

    def parse(self, xml_file):
        etree_file = open(xml_file)
        etree_content = etree_file.read()
        rx = re.compile("&#([0-9]+);|&#x([0-9a-fA-F]+);")
        endpos = len(etree_content)
        pos = 0
        while pos < endpos:
            # remove characters that don't conform to XML spec
            m = rx.search(etree_content, pos)
            if not m:
                break
            mstart, mend = m.span()
            target = m.group(1)
            if target:
                num = int(target)
            else:
                num = int(m.group(2), 16)
            # #x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]
            if not (
                num in (0x9, 0xA, 0xD) or
                0x20 <= num <= 0xD7FF or
                0xE000 <= num <= 0xFFFD or
                0x10000 <= num <= 0x10FFFF
            ):
                etree_content = etree_content[:mstart] + etree_content[mend:]
                endpos = len(etree_content)
            pos = mend

        try:
            root = ET.fromstring(etree_content)
        except ET.ParseError as e:
            self.logger.error('xml.etree.ElementTree.ParseError: %s' % e)
            self.logger.info('Please Check %s manually' % xml_file)
            return False
        self.logger.info(
            'Test modules in %s: %s'
            % (xml_file, str(len(root.findall('Module'))))
        )

        remaining_failures_to_print = self.failures_to_print
        for elem in root.findall('Module'):
            # Naming: Module Name + Test Case Name + Test Name
            if 'abi' in elem.attrib.keys():
                module_name = '.'.join(
                    [elem.attrib['abi'], elem.attrib['name']]
                )
            else:
                module_name = elem.attrib['name']

            if self.results_format == TradefedResultParser.AGGREGATED:
                r = self.print_aggregated(
                    module_name, elem, remaining_failures_to_print
                )
                remaining_failures_to_print -= r.num_printed_failures
                if r.failures_skipped:
                    self.logger.info(
                        'There are more than %d test cases '
                        'failed, the output for the rest '
                        'failed test cases will be '
                        'skipped.' % (self.failures_to_print)
                    )

            elif self.results_format == TradefedResultParser.ATOMIC:
                self.print_atomic(module_name, elem)
        return True

    def print_aggregated(self, module_name, elem, failures_to_print):
        tests_executed = len(elem.findall('.//Test'))
        tests_passed = len(elem.findall('.//Test[@result="pass"]'))
        tests_failed = len(elem.findall('.//Test[@result="fail"]'))

        result = '%s_executed pass %s' % (module_name, str(tests_executed))
        py_test_lib.add_result(self.result_output_file, result)

        result = '%s_passed pass %s' % (module_name, str(tests_passed))
        py_test_lib.add_result(self.result_output_file, result)

        failed_result = 'pass'
        if tests_failed > 0:
            failed_result = 'fail'
        result = '%s_failed %s %s' % (
            module_name,
            failed_result,
            str(tests_failed),
        )
        py_test_lib.add_result(self.result_output_file, result)

        # output result to show if the module is done or not
        tests_done = elem.get('done', 'false')
        if tests_done == 'false':
            result = '%s_done fail' % module_name
        else:
            result = '%s_done pass' % module_name
        py_test_lib.add_result(self.result_output_file, result)

        Result = collections.namedtuple(
            'Result', ['num_printed_failures', 'failures_skipped']
        )

        if failures_to_print == 0:
            return Result(0, False)

        # print failed test cases for debug
        num_printed_failures = 0
        test_cases = elem.findall('.//TestCase')
        for test_case in test_cases:
            failed_tests = test_case.findall('.//Test[@result="fail"]')
            for failed_test in failed_tests:
                if num_printed_failures == failures_to_print:
                    return Result(num_printed_failures, True)
                test_name = '%s/%s.%s' % (
                    module_name,
                    test_case.get("name"),
                    failed_test.get("name"),
                )
                failures = failed_test.findall('.//Failure')
                failure_msg = ''
                for failure in failures:
                    failure_msg = '%s \n %s' % (
                        failure_msg,
                        failure.get('message'),
                    )

                self.logger.info('%s %s' % (test_name, failure_msg.strip()))
                num_printed_failures += 1

        return Result(num_printed_failures, False)

    def print_atomic(self, module_name, elem):
        test_cases = elem.findall('.//TestCase')
        for test_case in test_cases:
            tests = test_case.findall('.//Test')
            for atomic_test in tests:
                atomic_test_result = atomic_test.get("result")
                atomic_test_name = "%s/%s.%s" % (
                    module_name,
                    test_case.get("name"),
                    atomic_test.get("name"),
                )
                py_test_lib.add_result(
                    self.result_output_file,
                    "%s %s" % (atomic_test_name, atomic_test_result),
                )
