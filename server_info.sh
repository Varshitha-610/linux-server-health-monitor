#!/bin/bash
echo "================================"
echo " Linux Server Health Check"
echo "================================"
echo "Check Time : $(date)"
echo ""
echo "===== SERVER INFORMATION ====="
log_file="/var/log/syslog"
health_status=0
name=$(whoami)
server=$(hostname)

echo "User   : $name"
echo "Server : $server"

echo ""
echo "===== SYSTEM HEALTH ====="

cpu_count=$(nproc)
memory_total=$(free -m | awk '/Mem:/ {print $2}')
memory_used=$(free -m | awk '/Mem:/ {print $3}')
memory_free=$(free -m | awk '/Mem:/ {print $4}')

echo "CPU Cores    : $cpu_count"
echo "Memory Total : ${memory_total} MB"
echo "Memory Used  : ${memory_used} MB"
echo "Memory Free  : ${memory_free} MB"

memory_usage=$((memory_used * 100 / memory_total))

echo "Memory Usage : ${memory_usage}%"

if [ "$memory_usage" -ge 80 ]; then
    echo "WARNING: Memory usage is 80% or higher"
    health_status=1
else
    echo "STATUS: Memory usage is normal"
fi
echo ""
echo "===== DISK HEALTH ====="

disk_usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')

echo "Disk Usage : ${disk_usage}%"

if [ "$disk_usage" -ge 80 ]; then
    echo "WARNING: Disk usage is 80% or higher"
    health_status=1
else
    echo "STATUS: Disk usage is normal"
fi

echo ""
echo "===== CPU LOAD ====="

cpu_count=$(nproc)
load_average=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1)

echo "CPU Cores    : $cpu_count"
echo "Load Average : $load_average"

if awk "BEGIN {exit !($load_average <= $cpu_count)}"; then
    echo "STATUS: CPU load is normal"
else
    echo "WARNING: CPU load is high"
fi

echo ""
echo "===== PROCESS HEALTH ====="

top_cpu=$(ps aux --sort=-%cpu | head -n 6)

echo "Top CPU Processes:"
echo "$top_cpu"

top_memory=$(ps aux --sort=-%mem | head -n 6)

echo ""
echo "Top Memory Processes:"
echo "$top_memory"
process_count=$(ps aux --no-headers | wc -l)

echo ""
echo "Total Processes : $process_count"
zombie_count=$(ps aux | awk '$8 ~ /^Z/ {count++} END {print count+0}')

echo "Zombie Processes : $zombie_count"
echo ""
echo "===== SERVICE HEALTH ====="

if systemctl is-active --quiet cron; then
    echo "Cron Service : RUNNING"
else
    echo "Cron Service : NOT RUNNING"
fi
echo "===== TOP LOG SOURCES ====="

grep -iE "error|fail|warning" "$log_file" \
    | awk '{print $3}' \
    | sort \
    | uniq -c \
    | sort -nr \
    | head -5
echo ""
echo "===== RECENT LOG PROBLEMS ====="

grep -iE "error|fail|warning" "$log_file" | tail -10
echo ""
echo "===== LOG HEALTH ====="

log_file="/var/log/syslog"

error_count=$(grep -i "error" "$log_file" | wc -l)
warning_count=$(grep -i "warning" "$log_file" | wc -l)
failure_count=$(grep -i "failed" "$log_file" | wc -l)

echo "Errors   : $error_count"
echo "Warnings : $warning_count"
echo "Failures : $failure_count"

if [ "$failure_count" -gt 0 ] || [ "$error_count" -gt 0 ]; then
    echo "LOG STATUS : WARNING"
    health_status=1
else
    echo "LOG STATUS : HEALTHY"
fi
echo ""
echo "===== FINAL STATUS ====="

if [ "$health_status" -eq 0 ]; then
    echo "OVERALL STATUS : HEALTHY"
else
    echo "OVERALL STATUS : WARNING"
fi

exit "$health_status"
