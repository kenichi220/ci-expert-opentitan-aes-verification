# ci-expert-opentitan-aes-verification

People involved:

- Felipe Nunes Laguna ([@FelipeNLaguna](https://github.com/FelipeNLaguna))
- Kenichi Brumati ([@Kenichi220](https://github.com/Kenichi220))
- Lorenzo Cadó Nemitz ([@Lorenzonemitz](https://github.com/Lorenzonemitz))

## Pkg
driver and monitor are class.
vif = virtual interface 
tb_top = constant with config-db

## Coommands to run
```bash
git clone https://github.com/kenichi220/ci-expert-opentitan-aes-verification.git && cd ci-expert-opentitan-aes-verification/uvm_aes/ && source env.sh && cd sim
```
```bash
make build && make test 
```
## Tools & Infrastructure

Verification is carried out with Synopsys EDA tools, running on the computing
infrastructure provided by CAD Micro (UFRGS).
