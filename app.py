#!/usr/bin/env python3
"""
CloudflareSpeedTest Web UI - 飞牛NAS一键部署版
基于 XIU2/CloudflareSpeedTest 的 Web 管理界面
"""

import json
import os
import signal
import subprocess
import threading
import time
import uuid
from datetime import datetime
from pathlib import Path

from flask import Flask, jsonify, render_template, request, Response

app = Flask(__name__, static_folder="web/static", template_folder="web/templates")

# ─── 配置 ───────────────────────────────────────────────────────────────────
CFST_BIN = os.environ.get("CFST_BIN", "/app/cfst")
DATA_DIR = os.environ.get("DATA_DIR", "/data")
IP_FILE = os.environ.get("IP_FILE", "/app/ip.txt")
RESULT_DIR = os.path.join(DATA_DIR, "results")
os.makedirs(RESULT_DIR, exist_ok=True)

# ─── 全局状态 ─────────────────────────────────────────────────────────────────
current_task = {
    "id": None,
    "status": "idle",       # idle | running | finished | error | stopped
    "progress": "",
    "log_lines": [],
    "result_csv": None,
    "result_json": [],
    "start_time": None,
    "end_time": None,
    "params": {},
}
task_lock = threading.Lock()
task_process = None


def reset_task():
    global current_task
    with task_lock:
        current_task = {
            "id": None,
            "status": "idle",
            "progress": "",
            "log_lines": [],
            "result_csv": None,
            "result_json": [],
            "start_time": None,
            "end_time": None,
            "params": {},
        }


def parse_result_csv(csv_path):
    """解析 result.csv 为 JSON 数组"""
    results = []
    if not os.path.exists(csv_path):
        return results
    with open(csv_path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    if len(lines) < 2:
        return results
    headers = [h.strip() for h in lines[0].split(",")]
    for line in lines[1:]:
        line = line.strip()
        if not line:
            continue
        values = [v.strip() for v in line.split(",")]
        if len(values) >= len(headers):
            row = {}
            for i, h in enumerate(headers):
                row[h] = values[i]
            results.append(row)
    return results


def run_cfst_task(params):
    """在后台线程中运行 CloudflareSpeedTest"""
    global current_task, task_process

    task_id = str(uuid.uuid4())[:8]
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    result_file = os.path.join(RESULT_DIR, f"result_{timestamp}.csv")

    with task_lock:
        current_task["id"] = task_id
        current_task["status"] = "running"
        current_task["start_time"] = datetime.now().isoformat()
        current_task["params"] = params
        current_task["log_lines"] = []
        current_task["result_csv"] = None
        current_task["result_json"] = []

    # 构建命令
    cmd = [CFST_BIN]

    # 线程数
    if params.get("threads"):
        cmd.extend(["-n", str(params["threads"])])
    # 测速次数
    if params.get("ping_times"):
        cmd.extend(["-t", str(params["ping_times"])])
    # 下载测速数量
    if params.get("download_count"):
        cmd.extend(["-dn", str(params["download_count"])])
    # 下载测速时间
    if params.get("download_time"):
        cmd.extend(["-dt", str(params["download_time"])])
    # 端口
    if params.get("port"):
        cmd.extend(["-tp", str(params["port"])])
    # 测速地址
    if params.get("url"):
        cmd.extend(["-url", params["url"]])
    # HTTPing 模式
    if params.get("httping"):
        cmd.append("-httping")
    # HTTPing 状态码
    if params.get("httping_code"):
        cmd.extend(["-httping-code", str(params["httping_code"])])
    # 匹配地区
    if params.get("cfcolo"):
        cmd.extend(["-cfcolo", params["cfcolo"]])
    # 延迟上限
    if params.get("max_delay"):
        cmd.extend(["-tl", str(params["max_delay"])])
    # 延迟下限
    if params.get("min_delay"):
        cmd.extend(["-tll", str(params["min_delay"])])
    # 丢包率上限
    if params.get("max_loss"):
        cmd.extend(["-tlr", str(params["max_loss"])])
    # 速度下限
    if params.get("min_speed"):
        cmd.extend(["-sl", str(params["min_speed"])])
    # 显示数量
    if params.get("print_num"):
        cmd.extend(["-p", str(params["print_num"])])
    # IP 段文件
    ip_file = params.get("ip_file", IP_FILE)
    if os.path.exists(ip_file):
        cmd.extend(["-f", ip_file])
    # 指定 IP
    if params.get("ip_text"):
        cmd.extend(["-ip", params["ip_text"]])
    # 输出文件
    cmd.extend(["-o", result_file])
    # 禁用下载测速
    if params.get("disable_download"):
        cmd.append("-dd")
    # 测速全部 IP
    if params.get("all_ip"):
        cmd.append("-allip")
    # 调试模式
    if params.get("debug"):
        cmd.append("-debug")

    with task_lock:
        current_task["log_lines"].append(f"[启动] 命令: {' '.join(cmd)}")
        current_task["log_lines"].append(f"[启动] 时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    try:
        task_process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )

        for line in iter(task_process.stdout.readline, ""):
            line = line.rstrip("\n")
            with task_lock:
                current_task["log_lines"].append(line)
                current_task["progress"] = line

        task_process.wait()
        returncode = task_process.returncode

        with task_lock:
            if current_task["status"] == "stopped":
                current_task["log_lines"].append("[完成] 测速已手动停止")
            elif returncode == 0:
                current_task["log_lines"].append("[完成] 测速完成！")
                current_task["status"] = "finished"
            else:
                current_task["log_lines"].append(f"[错误] 进程退出码: {returncode}")
                current_task["status"] = "error"

            current_task["end_time"] = datetime.now().isoformat()

            # 解析结果
            if os.path.exists(result_file):
                current_task["result_csv"] = result_file
                current_task["result_json"] = parse_result_csv(result_file)
                current_task["log_lines"].append(
                    f"[结果] 共 {len(current_task['result_json'])} 条记录"
                )

    except FileNotFoundError:
        with task_lock:
            current_task["status"] = "error"
            current_task["log_lines"].append(f"[错误] 找不到 CloudflareSpeedTest 可执行文件: {CFST_BIN}")
            current_task["end_time"] = datetime.now().isoformat()
    except Exception as e:
        with task_lock:
            current_task["status"] = "error"
            current_task["log_lines"].append(f"[错误] {str(e)}")
            current_task["end_time"] = datetime.now().isoformat()
    finally:
        task_process = None


# ─── 路由 ────────────────────────────────────────────────────────────────────

@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/start", methods=["POST"])
def start_task():
    with task_lock:
        if current_task["status"] == "running":
            return jsonify({"ok": False, "msg": "已有测速任务正在运行"}), 409

    reset_task()
    params = request.get_json(silent=True) or {}
    t = threading.Thread(target=run_cfst_task, args=(params,), daemon=True)
    t.start()
    return jsonify({"ok": True, "msg": "测速任务已启动"})


@app.route("/api/stop", methods=["POST"])
def stop_task():
    global task_process
    with task_lock:
        if current_task["status"] != "running":
            return jsonify({"ok": False, "msg": "没有正在运行的任务"}), 400
        current_task["status"] = "stopped"

    if task_process:
        try:
            task_process.send_signal(signal.SIGINT)
            time.sleep(2)
            if task_process and task_process.poll() is None:
                task_process.kill()
        except Exception:
            pass
    return jsonify({"ok": True, "msg": "已发送停止信号"})


@app.route("/api/status")
def get_status():
    with task_lock:
        return jsonify({
            "id": current_task["id"],
            "status": current_task["status"],
            "progress": current_task["progress"],
            "log_count": len(current_task["log_lines"]),
            "result_count": len(current_task["result_json"]),
            "start_time": current_task["start_time"],
            "end_time": current_task["end_time"],
            "params": current_task["params"],
        })


@app.route("/api/log")
def get_log():
    """获取日志，支持增量拉取"""
    offset = int(request.args.get("offset", 0))
    with task_lock:
        lines = current_task["log_lines"][offset:]
        return jsonify({
            "offset": offset,
            "lines": lines,
            "total": len(current_task["log_lines"]),
        })


@app.route("/api/result")
def get_result():
    with task_lock:
        return jsonify({
            "results": current_task["result_json"],
            "csv_file": current_task["result_csv"],
        })


@app.route("/api/result/csv")
def download_csv():
    with task_lock:
        csv_path = current_task["result_csv"]
    if not csv_path or not os.path.exists(csv_path):
        return jsonify({"ok": False, "msg": "没有可用的结果文件"}), 404

    def generate():
        with open(csv_path, "r", encoding="utf-8") as f:
            yield from f

    return Response(
        generate(),
        mimetype="text/csv",
        headers={"Content-Disposition": "attachment; filename=result.csv"},
    )


@app.route("/api/history")
def list_history():
    """列出历史测速结果"""
    results = []
    for fname in sorted(os.listdir(RESULT_DIR), reverse=True):
        if fname.startswith("result_") and fname.endswith(".csv"):
            fpath = os.path.join(RESULT_DIR, fname)
            records = parse_result_csv(fpath)
            results.append({
                "filename": fname,
                "path": fpath,
                "count": len(records),
                "time": fname.replace("result_", "").replace(".csv", ""),
            })
    return jsonify({"history": results[:50]})


@app.route("/api/history/<filename>")
def get_history_result(filename):
    """获取指定历史结果"""
    fpath = os.path.join(RESULT_DIR, filename)
    if not os.path.exists(fpath):
        return jsonify({"ok": False, "msg": "文件不存在"}), 404
    records = parse_result_csv(fpath)
    return jsonify({"results": records, "filename": filename})


@app.route("/api/history/<filename>/csv")
def download_history_csv(filename):
    fpath = os.path.join(RESULT_DIR, filename)
    if not os.path.exists(fpath):
        return jsonify({"ok": False, "msg": "文件不存在"}), 404

    def generate():
        with open(fpath, "r", encoding="utf-8") as f:
            yield from f

    return Response(
        generate(),
        mimetype="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )


@app.route("/api/config", methods=["GET"])
def get_config():
    """获取当前配置（IP 文件内容等）"""
    ip_content = ""
    if os.path.exists(IP_FILE):
        with open(IP_FILE, "r") as f:
            ip_content = f.read()
    return jsonify({
        "ip_file": IP_FILE,
        "ip_content": ip_content,
        "cfst_bin": CFST_BIN,
        "data_dir": DATA_DIR,
    })


@app.route("/api/config/ip", methods=["POST"])
def update_ip_config():
    """更新 IP 段配置"""
    data = request.get_json(silent=True) or {}
    content = data.get("content", "")
    target = data.get("target", IP_FILE)
    try:
        with open(target, "w") as f:
            f.write(content)
        return jsonify({"ok": True, "msg": "IP 配置已更新"})
    except Exception as e:
        return jsonify({"ok": False, "msg": str(e)}), 500


@app.route("/api/health")
def health():
    bin_exists = os.path.exists(CFST_BIN)
    return jsonify({
        "status": "ok" if bin_exists else "error",
        "binary": bin_exists,
        "version": "2.3.5",
    })


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port, debug=False)
