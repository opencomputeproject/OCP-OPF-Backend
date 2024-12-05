resource cluster {
	handlers {
		split-brain "/usr/lib/drbd/notify-split-brain.sh root";
		pri-lost-after-sb "/usr/bin/sb-recover.sh";
	}
	net {
		after-sb-0pri discard-zero-changes;
		after-sb-1pri discard-secondary;
		after-sb-2pri call-pri-lost-after-sb;
	}
        on cluster1 {
                device /dev/drbd0;
                disk /dev/nvme0n1;
                        meta-disk internal;
                        address 10.0.100.2:7789;
        }
        on cluster2 {
                device /dev/drbd0;
                disk /dev/nvme0n1;
                        meta-disk internal;
                        address 10.0.100.3:7789;
        }
}

