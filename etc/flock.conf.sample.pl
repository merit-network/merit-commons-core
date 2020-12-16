{
    # type of flock
    aws => 1,
    
    # toogle FlockVPN 1 == on, 0 == off.
    flock_vpn => 0,

    # the name of the meritcommons flock network interface
    flock_netif_name => 'aca0',

    # the subnet you want to use for FlockVPN
    flock_subnet => '10.0.0.0/24',

    # 32 character password to protect your flock's comms.
    flock_password => 'jCKcNWzCUXK7e5yargcCiFlfik44TIxj',

    # port for the FlockVPN, supernode is this + 1.
    flock_port => '1143',

    # flock supernode address
    flock_supernode_ip => '192.168.0.52',

    # flock network name (you shouldn't have to change this)
    flock_network_name => 'meritcommons-flock',

    ## FLOCK COORDINATOR OPTIONS

    # is this node a flock coordinator? 1 == yes, 0 == no
    flock_coordinator => 0,

    # aws region this flock is in
    flock_aws_region => 'us-east-1',

    # AWS tag you tag your flock instances with
    flock_aws_node_tag => 'flock-node',

    # AWS security group to assign to your flock nodes
    flock_aws_security_groups => ['meritcommons-app-server'],

    # the number of seconds to wait after a scale up event has finished before scaling up again
    flock_aws_scaleup_cooldown => 120,

    # the number of seconds to wait after any scale event has happened before scaling down
    flock_aws_scaledown_cooldown => 3570,

    # when scaling vertically, the number of seconds lower performing nodes being replaced remain up along side their faster replacements
    flock_aws_scale_overlap => 60,

    # CIDR of VPC subnet
    flock_aws_vpc_subnet => '10.10.0.0/24',

    # the AWS Route 53 hosted zone id
    flock_aws_dns_hosted_zone => 'Z3J7PRMFUCPJXA',

    # start the flock when the coordinator starts?
    flock_autostart => 1,

    # what zmq stats should cause the flock to scale up or down?  Valid values are: NODE_LOAD and NODE_CPU.
    flock_scale_on => 'NODE_LOAD',

    # the scale pattern that this flock coordinator should flollow
    flock_aws_scale_pattern => [
        {
            nodes => 1,
            instance_type => 'c3.large',
            hypnotoad_workers => 8,
            minion_workers => 4,
            description => "One c3.large instance; 2 Compute Cores",
            max_load => ['2', '1.5', '1'], # if these averages are observed across all nodes, advance to the next tier
            max_cpu => [80, 70], # 1m, 5m cpu% used
        },
        {
            nodes => 2,
            instance_type => 'c3.large',
            hypnotoad_workers => 8,
            minion_workers => 4,
            description => "Two c3.large instances; 4 Compute Cores",
            max_load => ['2', '1.5', '1'], # if these averages are observed across all nodes, advance to the next tier
            min_load => ['0', '0', '0'], # if these averages are observed across all nodes, descend to the previous tier
            max_cpu => [80, 70], # 1m, 5m cpu% used
            min_cpu => [10, 10], # 1m, 5m cpu% used
        },
        {
            nodes => 2,
            instance_type => 'c3.xlarge',
            hypnotoad_workers => 16,
            minion_workers => 8,
            description => "Two c3.xlarge instances; 8 Compute Cores",
            max_load => ['4', '3', '2'], # if these averages are observed across all nodes, advance to the next tier
            min_load => ['1', '0.5', '0.25'], # if these averages are observed across all nodes, descend to the previous tier
            max_cpu => [80, 70], # 1m, 5m cpu% used
            min_cpu => [10, 10], # 1m, 5m cpu% used
        },
        {
            nodes => 2,
            instance_type => 'c3.2xlarge',
            hypnotoad_workers => 32,
            minion_workers => 16,
            description => "Two c3.2xlarge instances; 16 Compute Cores",
            max_load => ['8', '6', '4'], # if these averages are observed across all nodes, advance to the next tier
            min_load => ['2', '1', '0.5'], # if these averages are observed across all nodes, descend to the previous tier
            max_cpu => [80, 70], # 1m, 5m cpu% used
            min_cpu => [10, 10], # 1m, 5m cpu% used
        },
        { 
            nodes => 3,
            instance_type => 'c3.2xlarge',
            hypnotoad_workers => 32,
            minion_workers => 16,
            description => "Three c3.2xlarge instances; 24 Compute Cores",
            max_load => ['8', '6', '4'], # if these averages are observed across all nodes, advance to the next tier
            min_load => ['2', '1', '0.5'], # if these averages are observed across all nodes, descend to the previous tier
            max_cpu => [80, 70], # 1m, 5m cpu% used
            min_cpu => [10, 10], # 1m, 5m cpu% used
        },
        {
            nodes => 4,
            instance_type => 'c3.2xlarge',
            hypnotoad_workers => 32,
            minion_workers => 16,
            description => "Four c3.2xlarge instances; 32 Compute Cores",
            min_load => ['2', '1', '0.5'], # if these averages are observed across all nodes, descend to the previous tier
            min_cpu => [10, 10], # 1m, 5m cpu% used
        },
    ],

    ## END FLOCK COORDINATOR OPTIONS
}