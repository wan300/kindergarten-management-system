import React, { useEffect, useState } from "react";
import { adminRequest } from "./api";

export default function AdminChildChatSessions() {
  const [sessions, setSessions] = useState([]);
  const [selectedSession, setSelectedSession] = useState(null);
  const [message, setMessage] = useState("");

  useEffect(() => {
    adminRequest("/admin/child_chat_sessions")
      .then((data) => {
        const records = Array.isArray(data) ? data : [];
        setSessions(records);
        setSelectedSession(records[0] || null);
      })
      .catch((err) => setMessage(err.message));
  }, []);

  return (
    <div>
      <h1 className="text-2xl font-semibold text-gray-900">儿童聊天记录</h1>
      <p className="mt-2 text-sm text-gray-500">查看儿童端与 DeepSeek 陪伴老师的历史对话。</p>
      {message ? <div className="mt-4 rounded bg-pink-50 p-3 text-pink-700">{message}</div> : null}

      <div className="mt-6 grid grid-cols-1 gap-4 lg:grid-cols-[320px_1fr]">
        <div className="rounded-md bg-white p-4 shadow-sm">
          <h2 className="font-semibold text-gray-900">对话列表</h2>
          <div className="mt-3 space-y-2">
            {sessions.map((session) => (
              <button
                key={session.id}
                className={`block w-full rounded border px-3 py-2 text-left text-sm ${selectedSession?.id === session.id ? "border-pink-600 bg-pink-50 text-pink-700" : "text-gray-700"}`}
                onClick={() => setSelectedSession(session)}>
                <span className="block font-medium">{session.student_name || "未知学生"}</span>
                <span className="block text-xs font-medium text-cyan-700">
                  {session.source === "device" ? `小智设备${session.device_id ? ` · ${session.device_id}` : ""}` : "儿童网页"}
                </span>
                <span className="block text-xs text-gray-500">{session.parent_name || "未知家长"} · {session.title || "儿童陪伴对话"}</span>
              </button>
            ))}
            {sessions.length === 0 ? <p className="text-sm text-gray-500">暂无儿童聊天记录。</p> : null}
          </div>
        </div>

        <div className="rounded-md bg-white p-4 shadow-sm">
          <h2 className="font-semibold text-gray-900">对话内容</h2>
          <div className="mt-3 space-y-3">
            {(selectedSession?.messages || []).map((item) => (
              <div key={item.id} className="rounded border p-3">
                <p className="text-xs text-gray-500">
                  {item.role === "user" ? "孩子" : "AI 陪伴老师"} · {new Date(item.created_at).toLocaleString()}
                </p>
                <p className="mt-1 whitespace-pre-wrap text-sm text-gray-800">{item.content}</p>
              </div>
            ))}
            {!selectedSession ? <p className="text-sm text-gray-500">请选择一个对话。</p> : null}
          </div>
        </div>
      </div>
    </div>
  );
}
