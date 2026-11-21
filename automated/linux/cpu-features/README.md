# cpu-features

Reads the AArch64 ID registers the way Linux presents them and decodes them
into Arm `FEAT_*` names, then checks them against a per-board list.

Files:

- `idregs.c`: static arm64 tool (nolibc, about 9 KB). `el0` lines: MRS of
  each ID register from EL0 on every CPU; Linux emulates these with its
  sanitised, user-visible value (MIDR, MPIDR and REVIDR are the CPU's own).
  `kvm` lines: `KVM_GET_ONE_REG` of a fresh vCPU, which carries the fields
  hidden from EL0 but not what KVM withholds from guests (SME,
  ID_AA64MMFR2_EL1.NV, MTE without the capability, ...). `kvm-mmfr2-nv`:
  the host's ID_AA64MMFR2_EL1.NV, probed through KVM's acceptance of a
  write of the host value. `kvm-vcpu-el2`: whether a vCPU with
  `KVM_ARM_VCPU_HAS_EL2` (nested virtualization) can be created.
- `idregs vec`: SVE/SME hwcaps, `PR_SVE_GET_VL`/`PR_SME_GET_VL`, and RDVL
  and RDSVL on every CPU (SIGILL when absent or trapped).
- `idregs pac`: pointer authentication exercised, per CPU (sign and
  authenticate with APIA, APIB, APDA, APDB and APGA; a wrong modifier must
  fault), at EL1 (`PR_PAC_RESET_KEYS` must change every key, which needs
  EL1 key register writes that EL3 does not trap) and under KVM (a guest
  at EL1 programs its own keys and signs; a vCPU without the ptrauth
  features must take UNDEFs).
- `idregs-arm64`: built from `idregs.c` by `make` (Makefile: NOLIBC= the
  tools/include/nolibc directory of a Linux tree, UAPI= arm64 kernel UAPI
  headers). Not committed: the test uses `-t <binary>`, an installed
  `idregs-arm64`, or builds it in place, and skips when none of these works.
- `feats.src`: FEAT_* name and condition `REG.FIELD>=VALUE` (field and
  value names of the Arm ARM as spelled in the kernel's
  `arch/arm64/tools/sysreg`).
- `features.txt`: the table the test reads, generated with
  `gen-feats.py <arch/arm64/tools/sysreg> <arch/arm64/kernel/cpufeature.c>
  feats.src > features.txt` (the committed table is from Linux v7.3-rc4):
  bit positions and values resolved; columns 8 and 9 say whether the
  kernel shows the field to EL0 (`v`/`h`, FTR_VISIBLE in cpufeature.c) and
  whether KVM carries it to a plain vCPU (`k`/`m`).

A feature counts as present when the EL0 or the KVM view shows it, absent
when every view that can show its fields shows none, and unknown
otherwise (for example a field hidden from EL0 on a kernel at EL1, where
there is no KVM): an expected feature that is unknown reports skip. Neither
view is the raw per-CPU register: both are the kernel's system-wide
sanitised value, so a feature only some CPUs have shows as absent (the
kernel logs a "SANITY CHECK" line for such a mismatch).

Parameters: `EXPECTED` (must be present) and `ABSENT` (must not be).
