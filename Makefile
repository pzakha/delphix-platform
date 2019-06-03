#
# Copyright 2018, 2019 Delphix
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

ALL_PLATFORMS := aws azure esx gcp kvm

#
# The version field defaults to a timestamp. Note that it can be
# overridden by running: make packages VERSION="<custom version>"
#
VERSION := $(shell date '+%Y.%m.%d.%H')

PKG_FILES := stage

.PHONY: \
	check \
	package \
	shellcheck \
	shfmtcheck

check: shellcheck shfmtcheck

packages: $(addprefix package-,$(ALL_PLATFORMS))

package-%:
	@rm -f debian/changelog
	@rm -rf $(PKG_FILES)

	dch --create --package delphix-platform -v $(VERSION) \
			"Automatically generated changelog entry."

	# Copy the files that should be in the package to the staging directory.
	mkdir $(PKG_FILES)
	cp -r files/common/* $(PKG_FILES)/
	if [ -d files/$*/ ]; then \
		cp -r files/$*/* $(PKG_FILES)/; \
	fi

	sed "s/@@TARGET_PLATFORM@@/$*/" \
		$(PKG_FILES)/var/lib/delphix-appliance/platform.in \
		>$(PKG_FILES)/var/lib/delphix-appliance/platform
	rm $(PKG_FILES)/var/lib/delphix-appliance/platform.in

	./scripts/download-signature-key.sh upgrade 5.3 \
		>$(PKG_FILES)/var/lib/delphix-appliance/key-public.pem.upgrade.5.3

	sed "s/@@TARGET_PLATFORM@@/$*/" debian/control.in >debian/control

	TARGET_PLATFORM=$* dpkg-buildpackage -us

	@for ext in buildinfo changes dsc tar.xz; do \
		mv -v ../delphix-platform_*.$$ext artifacts; \
	done

	@mv -v ../delphix-platform-$*_*_amd64.deb artifacts

SHELL_SCRIPTS := \
	debian/postinst \
	debian/prerm \
	usr/bin/download-latest-image \
	usr/bin/unpack-image \
	var/lib/delphix-platform/ansible/apply \
	var/lib/delphix-platform/os-migration

shellcheck:
	shellcheck $(SHELL_SCRIPTS)

shfmtcheck:
	! shfmt -d $(SHELL_SCRIPTS) | grep .
