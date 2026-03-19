import React from "react";
import "../styles.css";
import { exampleOptions } from "../utils/example_programs.js";

export default function CodeHeader({
  logoSrc,
  exampleValue,
  onExampleChange,
  sourceModeValue,
  sourceModeOptions = [],
  onSourceModeChange,
  compileProfile,
  conjAssocOptions = [],
  disjAssocOptions = [],
  delayPlacementOptions = [],
  onCompileProfileChange,
  modelValue,
  modelOptions = [],
  onModelChange,
  isFrozen,
}) {
  const availableExamples = exampleOptions();

  const renderOptions = (opts) =>
    opts.map(({ value, label }) => (
      <option key={value} value={value}>
        {label}
      </option>
    ));

  return (
    <div className="code-header">
      <a href="https://minikanren.org" target="_blank">
        <img src={logoSrc} alt="Logo" className="logo"/>
      </a>

      <div className="header-controls">
        <label className="select-group">
          <span className="select-label">Example</span>
          <select
            className="select"
            value={exampleValue}
            onChange={(e) => onExampleChange(e.target.value)}
            disabled={isFrozen}
          >
            {renderOptions(availableExamples)}
          </select>
        </label>

        <label className="select-group">
          <span className="select-label">Source</span>
          <select
            className="select"
            value={sourceModeValue}
            onChange={(e) => onSourceModeChange(e.target.value)}
            disabled={isFrozen}
          >
            {renderOptions(sourceModeOptions)}
          </select>
        </label>

        <label className="select-group">
          <span className="select-label">Conj</span>
          <select
            className="select"
            value={compileProfile.conjAssoc}
            onChange={(e) => onCompileProfileChange("conjAssoc", e.target.value)}
            disabled={isFrozen}
          >
            {renderOptions(conjAssocOptions)}
          </select>
        </label>

        <label className="select-group">
          <span className="select-label">Disj</span>
          <select
            className="select"
            value={compileProfile.disjAssoc}
            onChange={(e) => onCompileProfileChange("disjAssoc", e.target.value)}
            disabled={isFrozen}
          >
            {renderOptions(disjAssocOptions)}
          </select>
        </label>

        <label className="select-group">
          <span className="select-label">Delay</span>
          <select
            className="select"
            value={compileProfile.delayPlacement}
            onChange={(e) => onCompileProfileChange("delayPlacement", e.target.value)}
            disabled={isFrozen}
          >
            {renderOptions(delayPlacementOptions)}
          </select>
        </label>

        <label className="select-group">
          <span className="select-label">Model</span>
          <select
            className="select"
            value={modelValue}
            onChange={(e) => onModelChange(e.target.value)}
            disabled={isFrozen}
          >
            {renderOptions(modelOptions)}
          </select>
        </label>
      </div>
    </div>
  );
}
