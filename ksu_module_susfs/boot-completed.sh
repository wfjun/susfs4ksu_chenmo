#!/system/bin/sh
PATH=/data/adb/ksu/bin:$PATH

MODDIR=/data/adb/modules/susfs4ksu

SUSFS_BIN=/data/adb/ksu/bin/ksu_susfs

#### Manually add the sus mounts to susfs's try_umount list ####
## - Please note that the order matters as added paths are umounted in reversed order
## - It is suggested to add paths during boot-completed since most of mounts are done
##   in post-fs-data.sh or service.sh stage
cat <<EOF >/dev/null
# for /system/etc/hosts #
${SUSFS_BIN} add_try_umount /system/etc/hosts 1
# for lsposed, choose those that show up in your mountinfo, no need to add them all #
${SUSFS_BIN} add_try_umount /system/apex/com.android.art/bin/dex2oat 1
${SUSFS_BIN} add_try_umount /system/apex/com.android.art/bin/dex2oat32 1
${SUSFS_BIN} add_try_umount /system/apex/com.android.art/bin/dex2oat64 1
${SUSFS_BIN} add_try_umount /apex/com.android.art/bin/dex2oat 1
${SUSFS_BIN} add_try_umount /apex/com.android.art/bin/dex2oat32 1
${SUSFS_BIN} add_try_umount /apex/com.android.art/bin/dex2oat64 1
EOF

#### Auto retrieve sus mounts from /proc/1/mountinfo and add to try_umount ####
## - Create file to '/data/adb/susfs_no_auto_add_try_umount' if you want to disable
##   the auto add_try_umount
cat <<EOF >/dev/null
{
        if [ ! -f "/data/adb/susfs_no_auto_add_try_umount" ]; then
                cat /proc/1/mountinfo | grep -E "^500000 .* KSU .*$|^500000 .* shared:.*$" | awk '{print $5}' > /data/adb/sus_mounts.txt
                while read -r LINE; do
                        ${SUSFS_BIN} add_try_umount "${LINE}" 1
                done < /data/adb/sus_mounts.txt
        fi
}
EOF

#### Hide path like /sdcard/<target_root_dir> from all user app processes without root access ####
cat <<EOF >/dev/null
## First we need to wait until files are accessible in /sdcard ##
until [ -d "/sdcard/Android" ]; do sleep 1; done

## Next we need to set the path of /sdcard/ to tell kernel where the actual /sdcard is ##
ksu_susfs set_sdcard_root_path /sdcard

## Now we can add the path ##
ksu_susfs add_sus_path /sdcard/TWRP
ksu_susfs add_sus_path /sdcard/MT2

## Please note that sometimes the path needs to be added twice or above to be effective ##
## Besides, all user apps without root access cannot see the hidden path '/sdcard/<hidden_path>' unless you grant it root access ##
EOF

#### Hide the leaking app path like /sdcard/Android/data/<app_package_name> from syscall ####
cat <<EOF >/dev/null
## First we need to wait until files are accessible in /sdcard ##
until [ -d "/sdcard/Android" ]; do sleep 1; done

## Next we need to set the path of /sdcard/ to tell kernel where the actual /sdcard/Android/data is ##
ksu_susfs set_android_data_root_path /sdcard/Android/data

## Now we can add the path ##
ksu_susfs add_sus_path /sdcard/Android/data/bin.mt.plus
EOF

#### For path that needs to be re-flagged as SUS_PATH on each non-root user app / isolated service starts via add_sus_path_loop ####
cat <<EOF >/dev/null
## - Path added via add_sus_path_loop will be re-flagged as SUS_PATH on each non-root process / isolated service starts ##
## - This can help ensure some path that keep its inode status reset for whatever reason to be flagged as SUS_PATH again ##
## - Please also note that only paths NOT inside '/sdcard/' or '/storage/' can be added via add_sus_path_loop ##
## - ONLY USE THIS WHEN NECCESSARY !!! ##
ksu_susfs add_sus_path_loop /sys/block/loop0
EOF


#### Hide the mmapped real file from various maps in /proc/self/ ####
cat <<EOF >/dev/null
## - Please note that it is better to do it in boot-completed starge
##   Since some target path may be mounted by ksu, and make sure the
##   target path has the same dev number as the one in global mnt ns,
##   otherwise the sus map flag won't be seen on the umounted process.
## - To debug with this, users can do this in a root shell:
##   1. Find the pid and uid of a opened umounted app by running
##      ps -enf | grep myapp
##   2. cat /proc/<pid_of_myapp>/maps | grep "<added/sus_map/path>"'
##   3. In other root shell, run
##      cat /proc/1/mountinfo | grep "<added/sus_map/path>"'
##   4. Finally compare the dev number with both output and see if they are consistent,
##      if so, then it should be working, but if not, then the added sus_map path
##      is probably not working, and you have to find out which mnt ns the dev number
##      from step 2 belongs to, and add the path from that mnt ns:
##         busybox nsenter -t <pid_of_mnt_ns_the_target_dev_number_belongs_to> -m ksu_susfs add_sus_map <target_path>

## Hide some zygisk modules ##
ksu_susfs add_sus_map /data/adb/modules/my_module/zygisk/arm64-v8a.so

## Hide some map traces caused by some font modules ##
ksu_susfs add_sus_map /system/fonts/Roboto-Regular.ttf
ksu_susfs add_sus_map /system/fonts/RobotoStatic-Regular.ttf
EOF
