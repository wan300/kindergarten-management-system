import React from "react";

const DEFAULT_CHILD_DEV2_URL = "/child-growth/";

function childDev2Url() {
  const configuredUrl = process.env.REACT_APP_CHILD_DEV2_URL?.trim();
  return configuredUrl || DEFAULT_CHILD_DEV2_URL;
}

function ChildGrowth() {
  const appUrl = childDev2Url();

  return (
    <div className="flex h-[calc(100vh-4rem)] min-h-[680px] flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold text-gray-900">儿童成长OS</h1>
          <p className="mt-1 text-sm text-gray-500">独立子应用：{appUrl}</p>
        </div>
        <a
          className="rounded border border-gray-300 bg-white px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
          href={appUrl}
          rel="noreferrer"
          target="_blank">
          新窗口打开
        </a>
      </div>
      <iframe
        className="min-h-0 flex-1 rounded-md border border-gray-200 bg-white shadow-sm"
        src={appUrl}
        title="儿童成长OS"
      />
    </div>
  );
}

export default ChildGrowth;
