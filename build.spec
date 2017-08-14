%define debug_package %{nil}
AutoReq: 0
Name: %{_NAME}
Version: %{_version}
Release: %{_release}
Summary: taskeduler package
Prefix: %{_LOCATION}


requires: erlang >= 19.2

Group: System/Tools
License: Proprietary
URL: https://github.com/elpaisa/taskeduler
Source0: build.tar.gz
BuildRoot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-XXXXXX)
%description
Task Scheduler distributed Erlang Service

%prep
%setup -q -n src

%pre


%post

%install
pwd
mkdir -p %{buildroot}%{_LOCATION}
cp -aR * %{buildroot}%{_LOCATION}

%clean
rm -rf %{buildroot}

%files
%defattr(-,soc,soc,-)
%{_LOCATION}


%changelog
