# Appendix

## Default Component Version Matrix

`cyctl image build-rootfs` automatically selects matching container runtime and tool versions based on the specified K8s version:

| K8s Version | containerd | runc | crictl | registry |
|------------|-----------|------|--------|----------|
| ≤1.28 | 1.7.27 | 1.1.14 | 1.28.0 | 2.8.3 |
| 1.29 | 1.7.27 | 1.1.14 | 1.29.0 | 2.8.3 |
| 1.30 | 1.7.27 | 1.1.14 | 1.30.1 | 2.8.3 |
| 1.31 | 1.7.27 | 1.2.6 | 1.31.1 | 2.8.3 |
| 1.32 | 1.7.27 | 1.2.6 | 1.32.0 | 2.8.3 |
| 1.33 | 2.0.4 | 1.2.6 | 1.33.0 | 2.8.3 |
| 1.34+ | 2.1.1 | 1.2.6 | 1.33.0 | 2.8.3 |

> Starting from K8s 1.33, containerd 2.x is used by default. containerd 2.x removed the v1 CRI plugin config format — cyctl automatically generates the correct configuration for each version.
