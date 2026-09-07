import React from 'react';
import ToggleSwitch from './toggleSwitch.jsx';

const statusText = {
  idle: 'Ready', running: 'Running', paused: 'Paused at Delay',
  complete: 'Completed', stuck: 'Stuck',
};

export default function StepInfo({ step, stepName, executionStatus, answerCount,
  darkMode, setDarkMode }) {
  return (
    <div id="step-info" className="step-info-container">
      <div className="step-info-header">
        <div>
          Step: {step}<br/>
          Operation: {stepName}<br/>
          {statusText[executionStatus] ?? 'Ready'}
          {Number.isInteger(answerCount) && <> · {answerCount} committed answers</>}
        </div>
        <div style={{ marginRight: '50px' }}>
        <ToggleSwitch checked={darkMode} onChange={setDarkMode} />
      </div>
      </div>
    </div>
  );
}
