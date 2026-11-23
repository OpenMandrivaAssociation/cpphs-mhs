%global debug_package %{nil}
Summary:	cpphs 1.20.9 compiled by MicroHs
Name:		cpphs-mhs
Version:	1.20.9
Release:	1
License:	LGPL
Group:		Development/Other
Url:		https://hackage.haskell.org/package/cpphs
# Complement of distro cpphs. The binary is cpphs-mhs, so no Epoch.
# Three-round MicroHs build. Round 2 is installed after its C matches round 3.
ExclusiveArch:	x86_64 znver1
Source0:	cpphs-1.20.9.tar.gz
Source1:	polyparse-1.12.tar.gz
Source2:	MicroHs-0.16.6.0.tar.gz
Source3:	cpphs-1.20.9-mhs.patch
Source4:	polyparse-1.12-mhs.patch
Source5:	cpphs-mhs-build.sh
Source6:	%{name}.rpmlintrc

BuildRequires:	microhs
BuildRequires:	gcc
BuildRequires:	patch
BuildRequires:	grep
BuildRequires:	findutils

%description
cpphs 1.20.9 built from source by the packaged MicroHs compiler.
No prebuilt cpphs is used. The first round is preprocessed with gcc's
traditional cpp; the next two rounds preprocess themselves. The
installed binary is round 2, checked byte-for-byte against round 3.

Installed as %{_bindir}/cpphs-mhs so it does not replace distro cpphs.

%prep
set -eu
cd %{_builddir}
rm -rf cpphs-mhs-root
mkdir -p cpphs-mhs-root
cp -a %{SOURCE0} cpphs-mhs-root/cpphs-1.20.9.tar.gz
cp -a %{SOURCE1} cpphs-mhs-root/polyparse-1.12.tar.gz
cp -a %{SOURCE2} cpphs-mhs-root/MicroHs-0.16.6.0.tar.gz
cp -a %{SOURCE3} cpphs-mhs-root/cpphs-1.20.9-mhs.patch
cp -a %{SOURCE4} cpphs-mhs-root/polyparse-1.12-mhs.patch
set +u

%build
set -eu
bash %{SOURCE5} "%{_builddir}/cpphs-mhs-root" "%{_libdir}/mhs"
set +u

%install
set -eu
mkdir -p %{buildroot}%{_bindir}
install -m 755 %{_builddir}/cpphs-mhs-root/dest/bin/cpphs-mhs \
	%{buildroot}%{_bindir}/cpphs-mhs
set +u

%files
%{_bindir}/cpphs-mhs

%check
set -eu
b=%{buildroot}%{_bindir}/cpphs-mhs
ver=$("$b" --version | head -1)
printf '%s\n' "$ver" | grep -q '1.20.9'
printf '%s\n' 'main = putStrLn "ok"' > hello.hs
"$b" --noline hello.hs > hello.out
grep -q 'putStrLn' hello.out
set +u
