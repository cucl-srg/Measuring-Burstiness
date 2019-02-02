#!/bin/zsh

set -eu

source /root/jcw78/scripts/general/parse_config.sh
source /root/jcw78/scripts/general/remote_run.sh

if [[ $(dirname $0) != "." ]]; then
	cd $(dirname $0)
fi

runs=$(get_config_value Runs)
HPTMachine=$(get_config_value MachineB)

# First, setup the machines.
./setup_throuput_machines.sh

# Then, run all sub-tests:
echo "Running rate scan on a single port."
echo "Make sure port 0 of OSNT is connected to the HPT card."
cont_msg="Enter> to continue when this is done"
vared 'cont_msg'
pushd one_port_scan/
# ./run.sh
popd
echo "Finished running rate scan on a single port."
echo "Make sure wires are now configured so that port 0 of OSNT is connected through an optical tap to ports 0 and 1 of the HPT card"
cont_msg="Enter> to continue when this is done"
vared 'cont_msg'
pushd two_port_scan/
# These build up data accross runs.
remote_run_command $HPTMachine "echo -n '' > /root/jcw78/nvme/port0_data_builder"
remote_run_command $HPTMachine "echo -n '' > /root/jcw78/nvme/port1_data_builder"
for i in $(seq 1 $runs); do 
	./run.sh
	# We need to get the data out and keep it in a unified
	# file.
	remote_run_script $HPTMachine evaluation/hpt/throughput/two_port_scan/plot.sh /root/jcw78/nvme/two_port_scan
	# Get the data files out:
	remote_run_script $HPTMachine general/paste_wrapper.sh /root/jcw78/nvme/two_port_scan/both_ports_data /root/jcw78/nvme/both_ports_data_builder /root/jcw78/nvme/both_ports_data_builder

	# Archive the folders:
	remote_run_script $HPTMachine general/archive_results.sh /root/jcw78/nvme/two_port_scan/ /root/jcw78/nvme/two_port_scan_${i}.tar.bz2
done

# Run the analyses on the overall folders.
remote_run_script $HPTMachine $PWD/plot.sh /root/jcw78/nvme/port0_data_builder /root/jcw78/nvme/port1_data_builder

# Finally, move all the archived folders over to the LTS.
lts_dir=$(get_config_value LTSLocations)
remote_run_command $HPTMachine "mv /root/jcw78/nvme/two_port_scan_* $lts_dir"
remote_run_command $HPTMachine "mv /root/jcw78/nvme/both_ports_data_builder $lts_dir"

popd
echo "All done!"
