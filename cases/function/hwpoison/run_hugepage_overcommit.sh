#!/bin/bash

pushd `dirname $0` > /dev/null

. ./helpers.sh

load_hwpoison_inject

# make sure we have no hwpoisoned hugepage before starting this test.
free_resources > /dev/null

exec_testcase() {
	echo "-------------------------------------"
	local command="./thugetlb_overcommit 1"
	echo "TestCase $command"
	sysctl vm.nr_overcommit_hugepages
	sysctl vm.nr_hugepages
	cat /proc/meminfo
	sysctl vm.nr_overcommit_hugepages=10
	sysctl vm.nr_hugepages=1
	executed_testcase=$[executed_testcase+1]
	$command
	if [ $? -eq 0 ] ; then
		echo "$command returned with success."
	else
		failed_testcase=$[failed_testcase+1]
	fi
}

cat <<-EOF

***************************************************************************
Pay attention:

This test checks that hugepage soft-offlining works under overcommitting.
***************************************************************************


EOF

exec_testcase

free_resources

show_summary

popd > /dev/null

exit $failed_testcase
