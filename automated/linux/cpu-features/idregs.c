// SPDX-License-Identifier: BSD-2-Clause
// Copyright (c) 2026 Qualcomm Technologies, Inc. and/or its subsidiaries.
/*
 * idregs: print the AArch64 ID registers as Linux presents them.
 *
 *   el0 cpu<N> <REG> 0x<value>   MRS from EL0 on every online CPU. Linux
 *                                traps and emulates these: MIDR, MPIDR and
 *                                REVIDR are the CPU's own, the ID_AA64*
 *                                registers the system-wide sanitised value
 *                                with only the fields visible to user space.
 *   kvm <REG> 0x<value>          KVM_GET_ONE_REG on a fresh vCPU: the
 *                                sanitised value including hidden fields,
 *                                minus what KVM does not offer a guest.
 *   kvm-mmfr2-nv <n>             ID_AA64MMFR2_EL1.NV of the host: KVM clears
 *                                it in the guest view but accepts a write of
 *                                the host's value (set_id_aa64mmfr2_el1).
 *   kvm-cap <name> <n>           KVM_CHECK_EXTENSION.
 *   kvm-vcpu-el2 <ok|-errno>     KVM_ARM_VCPU_INIT with KVM_ARM_VCPU_HAS_EL2
 *                                (nested virtualization usable).
 *   vec ...                      ("idregs vec") SVE/SME hwcaps, prctl vector
 *                                lengths and RDVL/RDSVL on every CPU.
 *   pac ...                      ("idregs pac") pointer authentication used,
 *                                not just read: per CPU, a sign and
 *                                authenticate round trip with each of the
 *                                five keys and an authentication with a
 *                                wrong modifier, which must fault; at EL1,
 *                                PR_PAC_RESET_KEYS must change every key;
 *                                under KVM, a guest at EL1 programs its own
 *                                keys and signs, and a vCPU without the
 *                                ptrauth features must take UNDEFs.
 *
 * Built with nolibc: a static binary of a few KB, no C library needed on
 * the target.
 */
#include <linux/kvm.h>

#ifndef my_syscall3
#define my_syscall3 __nolibc_syscall3
#define my_syscall4 __nolibc_syscall4
#define my_syscall5 __nolibc_syscall5
#endif

#define S(op1, crn, crm, op2) (((3) << 14) | ((op1) << 11) | ((crn) << 7) | ((crm) << 3) | (op2))

struct reg {
	const char *name;
	unsigned int enc;
};

static const struct reg regs[] = {
	{ "MIDR_EL1", S(0, 0, 0, 0) },
	{ "MPIDR_EL1", S(0, 0, 0, 5) },
	{ "REVIDR_EL1", S(0, 0, 0, 6) },
	{ "ID_AA64PFR0_EL1", S(0, 0, 4, 0) },
	{ "ID_AA64PFR1_EL1", S(0, 0, 4, 1) },
	{ "ID_AA64PFR2_EL1", S(0, 0, 4, 2) },
	{ "ID_AA64ZFR0_EL1", S(0, 0, 4, 4) },
	{ "ID_AA64SMFR0_EL1", S(0, 0, 4, 5) },
	{ "ID_AA64FPFR0_EL1", S(0, 0, 4, 7) },
	{ "ID_AA64DFR0_EL1", S(0, 0, 5, 0) },
	{ "ID_AA64DFR1_EL1", S(0, 0, 5, 1) },
	{ "ID_AA64DFR2_EL1", S(0, 0, 5, 2) },
	{ "ID_AA64AFR0_EL1", S(0, 0, 5, 4) },
	{ "ID_AA64AFR1_EL1", S(0, 0, 5, 5) },
	{ "ID_AA64ISAR0_EL1", S(0, 0, 6, 0) },
	{ "ID_AA64ISAR1_EL1", S(0, 0, 6, 1) },
	{ "ID_AA64ISAR2_EL1", S(0, 0, 6, 2) },
	{ "ID_AA64ISAR3_EL1", S(0, 0, 6, 3) },
	{ "ID_AA64MMFR0_EL1", S(0, 0, 7, 0) },
	{ "ID_AA64MMFR1_EL1", S(0, 0, 7, 1) },
	{ "ID_AA64MMFR2_EL1", S(0, 0, 7, 2) },
	{ "ID_AA64MMFR3_EL1", S(0, 0, 7, 3) },
	{ "ID_AA64MMFR4_EL1", S(0, 0, 7, 4) },
	{ "CTR_EL0", S(3, 0, 0, 1) },
	{ "DCZID_EL0", S(3, 0, 0, 7) },
};

#define NREGS (sizeof(regs) / sizeof(regs[0]))

/* The MRS needs the encoding as an immediate. */
#define MRS(name) ({ unsigned long __v; __asm__ volatile("mrs %0, " name : "=r"(__v)); __v; })

static unsigned long el0_read(unsigned int i)
{
	switch (i) {
	case 0: return MRS("S3_0_C0_C0_0");
	case 1: return MRS("S3_0_C0_C0_5");
	case 2: return MRS("S3_0_C0_C0_6");
	case 3: return MRS("S3_0_C0_C4_0");
	case 4: return MRS("S3_0_C0_C4_1");
	case 5: return MRS("S3_0_C0_C4_2");
	case 6: return MRS("S3_0_C0_C4_4");
	case 7: return MRS("S3_0_C0_C4_5");
	case 8: return MRS("S3_0_C0_C4_7");
	case 9: return MRS("S3_0_C0_C5_0");
	case 10: return MRS("S3_0_C0_C5_1");
	case 11: return MRS("S3_0_C0_C5_2");
	case 12: return MRS("S3_0_C0_C5_4");
	case 13: return MRS("S3_0_C0_C5_5");
	case 14: return MRS("S3_0_C0_C6_0");
	case 15: return MRS("S3_0_C0_C6_1");
	case 16: return MRS("S3_0_C0_C6_2");
	case 17: return MRS("S3_0_C0_C6_3");
	case 18: return MRS("S3_0_C0_C7_0");
	case 19: return MRS("S3_0_C0_C7_1");
	case 20: return MRS("S3_0_C0_C7_2");
	case 21: return MRS("S3_0_C0_C7_3");
	case 22: return MRS("S3_0_C0_C7_4");
	case 23: return MRS("S3_3_C0_C0_1");
	case 24: return MRS("S3_3_C0_C0_7");
	}
	return 0;
}

static int set_cpu(int cpu)
{
	unsigned long mask[16] = { 0 };

	if (cpu >= (int)(sizeof(mask) * 8))
		return -1;
	mask[cpu / 64] = 1UL << (cpu % 64);
	return my_syscall3(__NR_sched_setaffinity, 0, sizeof(mask), mask);
}

static void el0(void)
{
	char path[64];
	unsigned int i;
	int cpu;

	for (cpu = 0; cpu < 1024; cpu++) {
		snprintf(path, sizeof(path), "/sys/devices/system/cpu/cpu%d", cpu);
		if (access(path, F_OK))
			break;
		if (set_cpu(cpu)) {
			printf("el0 cpu%d offline\n", cpu);
			continue;
		}
		for (i = 0; i < NREGS; i++)
			printf("el0 cpu%d %s 0x%016lx\n", cpu, regs[i].name, el0_read(i));
	}
}

static unsigned long long kvm_id(unsigned int enc)
{
	return KVM_REG_ARM64 | KVM_REG_SIZE_U64 | KVM_REG_ARM64_SYSREG | enc;
}

/* Leave the ptrauth vCPU features out (pac_guest negative case). */
static int no_ptrauth;
/* Leave the PMU out: KVM_RUN fails until a requested PMU is initialised. */
static int no_pmu;

static int vcpu_new(int kvm, unsigned int extra, int *vmfd)
{
	struct kvm_vcpu_init init;
	int vm, vcpu, sve;

	vm = ioctl(kvm, KVM_CREATE_VM, 0);
	if (vm < 0)
		return -errno;
	memset(&init, 0, sizeof(init));
	if (ioctl(vm, KVM_ARM_PREFERRED_TARGET, &init) < 0)
		return -errno;
	init.features[0] |= 1U << KVM_ARM_VCPU_PSCI_0_2;
	if (!no_pmu && ioctl(kvm, KVM_CHECK_EXTENSION, KVM_CAP_ARM_PMU_V3) > 0)
		init.features[0] |= 1U << KVM_ARM_VCPU_PMU_V3;
	if (!no_ptrauth &&
	    ioctl(kvm, KVM_CHECK_EXTENSION, KVM_CAP_ARM_PTRAUTH_ADDRESS) > 0 &&
	    ioctl(kvm, KVM_CHECK_EXTENSION, KVM_CAP_ARM_PTRAUTH_GENERIC) > 0)
		init.features[0] |= (1U << KVM_ARM_VCPU_PTRAUTH_ADDRESS) |
				    (1U << KVM_ARM_VCPU_PTRAUTH_GENERIC);
	sve = ioctl(kvm, KVM_CHECK_EXTENSION, KVM_CAP_ARM_SVE) > 0;
	if (sve)
		init.features[0] |= 1U << KVM_ARM_VCPU_SVE;
	init.features[0] |= extra;
	vcpu = ioctl(vm, KVM_CREATE_VCPU, 0);
	if (vcpu < 0)
		return -errno;
	if (ioctl(vcpu, KVM_ARM_VCPU_INIT, &init) < 0)
		return -errno;
	if (sve) {
		int what = KVM_ARM_VCPU_SVE;

		if (ioctl(vcpu, KVM_ARM_VCPU_FINALIZE, &what) < 0)
			return -errno;
	}
	*vmfd = vm;
	return vcpu;
}

static void kvm_view(void)
{
	static const struct { const char *name; int cap; } caps[] = {
		{ "ARM_PMU_V3", KVM_CAP_ARM_PMU_V3 },
		{ "ARM_SVE", KVM_CAP_ARM_SVE },
		{ "ARM_PTRAUTH_ADDRESS", KVM_CAP_ARM_PTRAUTH_ADDRESS },
		{ "ARM_MTE", KVM_CAP_ARM_MTE },
		{ "ARM_EL2", 240 },
		{ "ARM_EL2_E2H0", 241 },
	};
	struct kvm_one_reg r;
	unsigned long long v, mmfr2 = 0;
	unsigned int i;
	int kvm, vm, vcpu, k, nv = -1, have_mmfr2 = 0;

	kvm = open("/dev/kvm", O_RDWR);
	if (kvm < 0) {
		printf("kvm unavailable %d\n", -errno);
		return;
	}
	for (i = 0; i < sizeof(caps) / sizeof(caps[0]); i++)
		printf("kvm-cap %s %d\n", caps[i].name,
		       (int)ioctl(kvm, KVM_CHECK_EXTENSION, caps[i].cap));
	vcpu = vcpu_new(kvm, 0, &vm);
	if (vcpu < 0) {
		printf("kvm vcpu-failed %d\n", vcpu);
		return;
	}
	for (i = 0; i < NREGS; i++) {
		r.id = kvm_id(regs[i].enc);
		r.addr = (unsigned long)&v;
		if (ioctl(vcpu, KVM_GET_ONE_REG, &r) < 0) {
			printf("kvm %s error %d\n", regs[i].name, -errno);
			continue;
		}
		printf("kvm %s 0x%016llx\n", regs[i].name, v);
		if (regs[i].enc == S(0, 0, 7, 2)) {
			mmfr2 = v;
			have_mmfr2 = 1;
		}
	}
	if (have_mmfr2) {
		for (k = 1; k <= 2; k++) {
			v = (mmfr2 & ~(0xfULL << 24)) | ((unsigned long long)k << 24);
			r.id = kvm_id(S(0, 0, 7, 2));
			r.addr = (unsigned long)&v;
			if (ioctl(vcpu, KVM_SET_ONE_REG, &r) == 0)
				nv = k;
			v = mmfr2;
			ioctl(vcpu, KVM_SET_ONE_REG, &r);
		}
		printf("kvm-mmfr2-nv %d\n", nv < 0 ? 0 : nv);
	}
	vcpu = vcpu_new(kvm, 1U << 7 /* KVM_ARM_VCPU_HAS_EL2 */, &vm);
	if (vcpu < 0)
		printf("kvm-vcpu-el2 %d\n", vcpu);
	else
		printf("kvm-vcpu-el2 ok\n");
}

/*
 * Pointer authentication. The PAC instructions below are the non-hint
 * forms: UNDEFINED without FEAT_PAuth, a NOP when the kernel left the key
 * disabled (SCTLR_EL1.EnIA/EnIB/EnDA/EnDB), and they trap to EL3 when
 * SCR_EL3.API is clear. Everything that may fault runs in a child.
 */
#define PR_PAC_RESET_KEYS		54
#define PR_PAC_GET_ENABLED_KEYS		61

enum { KIA, KIB, KDA, KDB, NKEYS };
static const char *const keyname[] = { "APIA", "APIB", "APDA", "APDB", "APGA" };

static unsigned long pac_sign(int k, unsigned long p, unsigned long m)
{
	switch (k) {
	case KIA: __asm__ volatile("pacia %0, %1" : "+r"(p) : "r"(m)); break;
	case KIB: __asm__ volatile("pacib %0, %1" : "+r"(p) : "r"(m)); break;
	case KDA: __asm__ volatile("pacda %0, %1" : "+r"(p) : "r"(m)); break;
	case KDB: __asm__ volatile("pacdb %0, %1" : "+r"(p) : "r"(m)); break;
	}
	return p;
}

static unsigned long pac_auth(int k, unsigned long p, unsigned long m)
{
	switch (k) {
	case KIA: __asm__ volatile("autia %0, %1" : "+r"(p) : "r"(m)); break;
	case KIB: __asm__ volatile("autib %0, %1" : "+r"(p) : "r"(m)); break;
	case KDA: __asm__ volatile("autda %0, %1" : "+r"(p) : "r"(m)); break;
	case KDB: __asm__ volatile("autdb %0, %1" : "+r"(p) : "r"(m)); break;
	}
	return p;
}

static unsigned long pac_ga(unsigned long p, unsigned long m)
{
	unsigned long r;

	__asm__ volatile("pacga %0, %1, %2" : "=r"(r) : "r"(p), "r"(m));
	return r;
}

static volatile unsigned long target = 0x5a5a5a5a;

struct pac_out {
	unsigned long sign[NKEYS + 1], auth[NKEYS];
	unsigned long reset[NKEYS + 1];
	long enabled;
};

/* run fn(arg) in a child: "exit <code>" or "signal <n>" */
static const char *child(void (*fn)(int, struct pac_out *), int arg, struct pac_out *o, int *code)
{
	int st = 0;
	pid_t pid = fork();

	if (pid == 0) {
		fn(arg, o);
		exit(0);
	}
	waitpid(pid, &st, 0);
	if (WIFSIGNALED(st)) {
		*code = WTERMSIG(st);
		return "signal";
	}
	*code = (st >> 8) & 0xff;
	return "exit";
}

/*
 * A data pointer PAC is only a few bits wide (bits 54:48 with a 48-bit VA
 * and TBI), so one signature equals the plain pointer, or an old one, with
 * a probability of 1/128: every comparison below uses eight modifiers.
 */
#define NMOD 8

static void roundtrip(int unused, struct pac_out *o)
{
	unsigned long p = (unsigned long)&target, s;
	int k, m;

	for (k = 0; k < NKEYS; k++) {
		o->sign[k] = pac_sign(k, p, 42);
		o->auth[k] = pac_auth(k, o->sign[k], 42);
		/* report a signature that differs from p when any modifier gives one */
		for (m = 0; m < NMOD && o->sign[k] == p; m++) {
			s = pac_sign(k, p, 100 + m);
			if (pac_auth(k, s, 100 + m) != p)
				o->auth[k] = 0;
			if (s != p)
				o->sign[k] = s;
		}
	}
	o->sign[NKEYS] = pac_ga(p, 42);
}

/* Authenticate with wrong modifiers and use the result: must fault. */
static void corrupt(int k, struct pac_out *o)
{
	unsigned long p = (unsigned long)&target, s = pac_sign(k, p, 42), a;
	unsigned long m;

	for (m = 43; m < 47; m++) {
		a = pac_auth(k, s, m);
		(void)*(volatile unsigned long *)a;
	}
	exit(3);
}

static void reset(int unused, struct pac_out *o)
{
	unsigned long p = (unsigned long)&target, before[NKEYS + 1][NMOD];
	int k, m;

	for (k = 0; k < NKEYS; k++)
		for (m = 0; m < NMOD; m++)
			before[k][m] = pac_sign(k, p, 42 + m);
	for (m = 0; m < NMOD; m++)
		before[NKEYS][m] = pac_ga(p, 42 + m);
	o->enabled = my_syscall5(__NR_prctl, PR_PAC_GET_ENABLED_KEYS, 0, 0, 0, 0);
	if (my_syscall5(__NR_prctl, PR_PAC_RESET_KEYS, 0, 0, 0, 0))
		exit(4);
	for (k = 0; k < NKEYS; k++)
		for (m = 0; m < NMOD; m++)
			o->reset[k] |= before[k][m] != pac_sign(k, p, 42 + m);
	for (m = 0; m < NMOD; m++)
		o->reset[NKEYS] |= before[NKEYS][m] != pac_ga(p, 42 + m);
}

static void pac_el0(void)
{
	struct pac_out *o = mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_SHARED | MAP_ANONYMOUS, -1, 0);
	char path[64];
	const char *how;
	int cpu, k, code;

	unsigned long nocore[2] = { 0, 0 };

	/* The faults below are expected: no core files. */
	my_syscall4(__NR_prlimit64, 0, RLIMIT_CORE, nocore, 0);
	printf("pac hwcap paca %lu pacg %lu\n", (getauxval(AT_HWCAP) >> 30) & 1,
	       (getauxval(AT_HWCAP) >> 31) & 1);
	for (cpu = 0; cpu < 1024; cpu++) {
		snprintf(path, sizeof(path), "/sys/devices/system/cpu/cpu%d", cpu);
		if (access(path, F_OK))
			break;
		if (set_cpu(cpu))
			continue;
		memset(o, 0, sizeof(*o));
		how = child(roundtrip, 0, o, &code);
		if (strcmp(how, "exit") || code) {
			printf("pac cpu%d roundtrip %s %d\n", cpu, how, code);
			continue;
		}
		for (k = 0; k < NKEYS; k++)
			printf("pac cpu%d %s sign 0x%016lx auth 0x%016lx %s\n", cpu, keyname[k],
			       o->sign[k], o->auth[k],
			       o->auth[k] != (unsigned long)&target ? "auth-mismatch" :
			       o->sign[k] == (unsigned long)&target ? "unsigned" : "ok");
		printf("pac cpu%d APGA pac 0x%016lx %s\n", cpu, o->sign[NKEYS],
		       o->sign[NKEYS] >> 32 ? "ok" : "zero");
		for (k = 0; k < NKEYS; k++) {
			how = child(corrupt, k, o, &code);
			printf("pac cpu%d %s corrupt %s %d\n", cpu, keyname[k], how, code);
		}
	}
	set_cpu(0);
	memset(o, 0, sizeof(*o));
	how = child(reset, 0, o, &code);
	if (strcmp(how, "exit") || code) {
		printf("pac reset %s %d\n", how, code);
		return;
	}
	printf("pac enabled-keys 0x%lx\n", o->enabled);
	for (k = 0; k <= NKEYS; k++)
		printf("pac reset %s %s\n", keyname[k], o->reset[k] ? "changed" : "unchanged");
}

/*
 * The KVM guest: EL1, MMU off. It installs a vector table, programs all
 * five keys, enables the four pointer keys in SCTLR_EL1 and reports through
 * MMIO stores to 0x10000000: +0x00.. sign/auth/wrong-modifier for APIA,
 * APIB, APDA, APDB (0x18 apart), +0x60 PACGA, +0x68 done, +0x70 the ESR of
 * the last exception and +0x78 the number of exceptions.
 */
__asm__(
	".pushsection .text.guest, \"ax\"\n"
	".balign 4096\n"
	".globl guest_start\n"
	"guest_start:\n"
	"	adr	x9, 9f\n"
	"	msr	vbar_el1, x9\n"
	"	movz	x10, #0x1000, lsl #16\n"
	"	mov	x11, #0\n"
	"	isb\n"
	"	movz	x2, #0x1234\n	movk	x2, #0x5678, lsl #16\n	movk	x2, #0x9abc, lsl #32\n"
	"	movz	x3, #0x4321\n	movk	x3, #0x8765, lsl #16\n	movk	x3, #0xcba9, lsl #48\n"
	"	msr	S3_0_C2_C1_0, x2\n	msr	S3_0_C2_C1_1, x3\n"
	"	msr	S3_0_C2_C1_2, x3\n	msr	S3_0_C2_C1_3, x2\n"
	"	msr	S3_0_C2_C2_0, x2\n	msr	S3_0_C2_C2_1, x2\n"
	"	msr	S3_0_C2_C2_2, x3\n	msr	S3_0_C2_C2_3, x3\n"
	"	msr	S3_0_C2_C3_0, x3\n	msr	S3_0_C2_C3_1, x2\n"
	"	mov	x4, #16\n	msr	tcr_el1, x4\n"
	"	mrs	x3, sctlr_el1\n"
	"	movz	x4, #0xc800, lsl #16\n"
	"	orr	x4, x4, #0x2000\n"
	"	orr	x3, x3, x4\n"
	"	msr	sctlr_el1, x3\n"
	"	isb\n"
	"	movz	x0, #0x8000, lsl #16\n"
	"	mov	x1, #42\n	mov	x6, #43\n"
	"	mov	x5, x0\n	pacia	x5, x1\n	str	x5, [x10, #0x00]\n"
	"	autia	x5, x1\n	str	x5, [x10, #0x08]\n"
	"	mov	x5, x0\n	pacia	x5, x1\n	autia	x5, x6\n	str	x5, [x10, #0x10]\n"
	"	mov	x5, x0\n	pacib	x5, x1\n	str	x5, [x10, #0x18]\n"
	"	autib	x5, x1\n	str	x5, [x10, #0x20]\n"
	"	mov	x5, x0\n	pacib	x5, x1\n	autib	x5, x6\n	str	x5, [x10, #0x28]\n"
	"	mov	x5, x0\n	pacda	x5, x1\n	str	x5, [x10, #0x30]\n"
	"	autda	x5, x1\n	str	x5, [x10, #0x38]\n"
	"	mov	x5, x0\n	pacda	x5, x1\n	autda	x5, x6\n	str	x5, [x10, #0x40]\n"
	"	mov	x5, x0\n	pacdb	x5, x1\n	str	x5, [x10, #0x48]\n"
	"	autdb	x5, x1\n	str	x5, [x10, #0x50]\n"
	"	mov	x5, x0\n	pacdb	x5, x1\n	autdb	x5, x6\n	str	x5, [x10, #0x58]\n"
	"	pacga	x5, x0, x1\n	str	x5, [x10, #0x60]\n"
	"	mov	x5, #1\n	str	x5, [x10, #0x68]\n"
	"8:	wfi\n	b	8b\n"
	/* vectors: current EL with SP_ELx, synchronous at +0x200 */
	".balign 2048\n"
	"9:\n"
	".skip 0x200\n"
	"	mrs	x12, esr_el1\n	str	x12, [x10, #0x70]\n"
	"	add	x11, x11, #1\n	str	x11, [x10, #0x78]\n"
	"	mrs	x12, elr_el1\n	add	x12, x12, #4\n	msr	elr_el1, x12\n"
	"	eret\n"
	".balign 2048\n"
	".globl guest_end\n"
	"guest_end:\n"
	".popsection\n");
extern const char guest_start[], guest_end[];

#define GUEST_PA	0x80000000UL
#define GUEST_SIZE	0x10000UL
#define GUEST_MMIO	0x10000000UL

static void pac_guest(int kvm, const char *tag, int ptrauth)
{
	static const char *const what[] = { "sign", "auth", "wrong" };
	struct kvm_userspace_memory_region mr;
	struct kvm_one_reg r;
	struct kvm_run *run;
	unsigned long long pc = GUEST_PA, rep[16] = { 0 };
	unsigned long seen = 0;
	unsigned int extra = 0;
	int vm, vcpu, n, i, sz;
	void *mem;

	no_ptrauth = !ptrauth;
	no_pmu = 1;
	vcpu = vcpu_new(kvm, extra, &vm);
	no_ptrauth = no_pmu = 0;
	if (vcpu < 0) {
		printf("pac kvm-%s vcpu %d\n", tag, vcpu);
		return;
	}
	mem = mmap(NULL, GUEST_SIZE, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
	memcpy(mem, guest_start, guest_end - guest_start);
	mr.slot = 0;
	mr.flags = 0;
	mr.guest_phys_addr = GUEST_PA;
	mr.memory_size = GUEST_SIZE;
	mr.userspace_addr = (unsigned long)mem;
	if (ioctl(vm, KVM_SET_USER_MEMORY_REGION, &mr) < 0) {
		printf("pac kvm-%s memory %d\n", tag, -errno);
		return;
	}
	r.id = KVM_REG_ARM64 | KVM_REG_SIZE_U64 | KVM_REG_ARM_CORE | KVM_REG_ARM_CORE_REG(regs.pc);
	r.addr = (unsigned long)&pc;
	ioctl(vcpu, KVM_SET_ONE_REG, &r);
	sz = ioctl(kvm, KVM_GET_VCPU_MMAP_SIZE, 0);
	run = mmap(NULL, sz, PROT_READ | PROT_WRITE, MAP_SHARED, vcpu, 0);
	for (n = 0; n < 200 && !(seen & (1UL << 13)); n++) {
		if (ioctl(vcpu, KVM_RUN, 0) < 0) {
			printf("pac kvm-%s run %d\n", tag, -errno);
			return;
		}
		if (run->exit_reason != KVM_EXIT_MMIO || !run->mmio.is_write ||
		    run->mmio.phys_addr < GUEST_MMIO || run->mmio.phys_addr >= GUEST_MMIO + 0x80) {
			printf("pac kvm-%s exit %u\n", tag, run->exit_reason);
			return;
		}
		i = (run->mmio.phys_addr - GUEST_MMIO) / 8;
		memcpy(&rep[i], run->mmio.data, 8);
		seen |= 1UL << i;
	}
	for (i = 0; i < 12; i++)
		printf("pac kvm-%s %s %s 0x%016llx\n", tag, keyname[i / 3], what[i % 3], rep[i]);
	printf("pac kvm-%s APGA pac 0x%016llx\n", tag, rep[12]);
	printf("pac kvm-%s done %llu exceptions %llu esr 0x%llx\n", tag, rep[13], rep[15], rep[14]);
}

static void pac_kvm(void)
{
	int kvm = open("/dev/kvm", O_RDWR);

	if (kvm < 0) {
		printf("pac kvm unavailable %d\n", -errno);
		return;
	}
	printf("pac kvm-cap ptrauth-address %d generic %d\n",
	       (int)ioctl(kvm, KVM_CHECK_EXTENSION, KVM_CAP_ARM_PTRAUTH_ADDRESS),
	       (int)ioctl(kvm, KVM_CHECK_EXTENSION, KVM_CAP_ARM_PTRAUTH_GENERIC));
	pac_guest(kvm, "ptrauth", 1);
	pac_guest(kvm, "noptrauth", 0);
}

/*
 * SVE and SME used, not just read: hwcaps, prctl vector lengths, and on
 * every CPU RDVL (SVE) and RDSVL (SME) in a child, which take SIGILL when
 * the CPU lacks the extension or EL3/EL2/EL1 traps it (CPTR_EL3.EZ/ESM,
 * CPTR_EL2, CPACR_EL1).
 */
#define PR_SVE_GET_VL	51
#define PR_SME_GET_VL	64

static void do_rdvl(int unused, struct pac_out *o)
{
	unsigned long v;

	__asm__ volatile(".inst 0x04bf5020\n\tmov %0, x0" : "=r"(v) : : "x0");	/* rdvl x0, #1 */
	o->sign[0] = v;
}

static void do_rdsvl(int unused, struct pac_out *o)
{
	unsigned long v;

	__asm__ volatile(".inst 0x04bf5820\n\tmov %0, x0" : "=r"(v) : : "x0");	/* rdsvl x0, #1 */
	o->sign[0] = v;
}

static void sve_sme(void)
{
	struct pac_out *o = mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_SHARED | MAP_ANONYMOUS, -1, 0);
	unsigned long nocore[2] = { 0, 0 }, h = getauxval(AT_HWCAP), h2 = getauxval(AT_HWCAP2);
	char path[64];
	const char *how;
	int cpu, code;

	my_syscall4(__NR_prlimit64, 0, RLIMIT_CORE, nocore, 0);
	printf("vec hwcap sve %lu sve2 %lu sme %lu sme2 %lu\n", (h >> 22) & 1, (h2 >> 1) & 1,
	       (h2 >> 23) & 1, (h2 >> 37) & 1);
	printf("vec prctl sve-vl %ld sme-vl %ld\n",
	       (long)my_syscall5(__NR_prctl, PR_SVE_GET_VL, 0, 0, 0, 0),
	       (long)my_syscall5(__NR_prctl, PR_SME_GET_VL, 0, 0, 0, 0));
	for (cpu = 0; cpu < 1024; cpu++) {
		snprintf(path, sizeof(path), "/sys/devices/system/cpu/cpu%d", cpu);
		if (access(path, F_OK))
			break;
		if (set_cpu(cpu))
			continue;
		o->sign[0] = 0;
		how = child(do_rdvl, 0, o, &code);
		printf("vec cpu%d rdvl %s %d vl %lu\n", cpu, how, code, o->sign[0]);
		o->sign[0] = 0;
		how = child(do_rdsvl, 0, o, &code);
		printf("vec cpu%d rdsvl %s %d svl %lu\n", cpu, how, code, o->sign[0]);
	}
	set_cpu(0);
}

int main(int argc, char **argv)
{
	int do_el0 = 1, do_kvm = 1;

	if (argc > 1 && !strcmp(argv[1], "el0"))
		do_kvm = 0;
	if (argc > 1 && !strcmp(argv[1], "kvm"))
		do_el0 = 0;
	printf("idregs 1\n");
	if (argc > 1 && !strcmp(argv[1], "pac")) {
		pac_el0();
		pac_kvm();
		return 0;
	}
	if (argc > 1 && !strcmp(argv[1], "vec")) {
		sve_sme();
		return 0;
	}
	if (do_el0)
		el0();
	if (do_kvm)
		kvm_view();
	return 0;
}
