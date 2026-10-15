Name:           tlbstacks
Version:        0.3.1
Release:        0%{?dist}
Summary:        Application launchers, configurable stacks, and task management for KDE Plasma 6

License:        GPL-3.0-or-later
URL:            https://github.com/mattisking/tlb-stacks
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  extra-cmake-modules >= 6.0
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  kf6-kio-devel
BuildRequires:  kf6-kservice-devel
BuildRequires:  plasma-activities-devel
BuildRequires:  plasma-activities-stats-devel

Requires:       plasma-workspace
Requires:       kf6-kirigami
Requires:       kf6-kiconthemes
Requires:       python3

%description
TLBStacks provides KDE Plasma 6 widgets for launching and organizing
applications. The main widget, TLBStacks Groups, organizes applications into
compact launcher groups with individual launchers, configurable stacks, live
menus, and task management for running windows. The standalone TLBStacks
widget provides a single configurable stack.

%prep
%autosetup -n %{name}-%{version}

%build
%cmake

%cmake_build

%install
%cmake_install

%files
%license LICENSE
%doc README.md
%{_datadir}/plasma/plasmoids/com.mattphilmon.tlbstacks/
%{_datadir}/plasma/plasmoids/com.mattphilmon.tlbstacks.group/
%{_datadir}/licenses/tlb-stacks/
%{_libdir}/qt6/qml/com/mattphilmon/tlbstacks/

%changelog
* Mon Oct 12 2026 Matt Philmon <mattisking@users.noreply.github.com> - 0.3.1-0
- Initial packaging of TLBStacks and TLBStacks Groups 0.3.1
