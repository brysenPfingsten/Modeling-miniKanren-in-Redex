import React, { useEffect } from "react";
import "../styles.css";
import { examplesForModel } from "../utils/example_programs.js";


const modelOptions = [
  { value: "microKanren", label: "µKanren" },
  { value: "dmitry",      label: "Dmitry et al." },
  { value: "dfs",         label: "DFS"}
];

export default function CodeHeader({
  logoSrc,
  programText,
  onProgramChange,
  modelValue,
  onModelChange,
  isFrozen,
}) {
  const availableExamples = examplesForModel(modelValue);

  useEffect(() => {
    const stillAvailable = availableExamples.some((opt) => opt.value === programText);
    if (!stillAvailable) onProgramChange("");
  }, [availableExamples, programText, onProgramChange]);

  const renderOptions = (opts) =>
    opts.map(({ value, label }) => (
      <option key={value} value={value}>
        {label}
      </option>
    ));

  // TODO: Maybe add some error handling here
  const changeModel = async (newModel) => {
    onModelChange(newModel);
    fetch('api/post/model', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json'},
      body: JSON.stringify({ model: newModel})
    });
  }

  return (
    <div className="code-header">
      <a href="https://minikanren.org" target="_blank">
        <img src={logoSrc} alt="Logo" className="logo"/>
      </a>

      <select
        className="select"
        value={programText}
        onChange={(e) => onProgramChange(e.target.value)}
        disabled={isFrozen}
      >
        {renderOptions(availableExamples)}
      </select>

      <select
        className="select"
        value={modelValue}
        onChange={(e) => changeModel(e.target.value)}
        disabled={isFrozen}
      >
        {renderOptions(modelOptions)}
      </select>
    </div>
  ); }
