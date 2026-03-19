import React, { useState, useRef, useEffect } from 'react';
import { Scrollbar } from 'react-scrollbars-custom';
import CodeHeader      from './components/CodeHeader.jsx';
import CodeEditor      from './components/CodeEditor';
import Toolbar         from './components/Toolbar';
import StepInfo        from './components/StepInfo';
import TreeCanvas      from './components/TreeCanvas';
import CustomAlert     from './components/CustomAlert';
import useStepper      from './hooks/useStepper';
import Resizable       from './components/Resizable';
import Sidebar from './components/Sidebar';
import { DEFAULT_MODEL_OPTIONS, MODEL_IDS } from './utils/model_ids.js';
import { exampleById } from './utils/example_programs.js';
import {
  buildSourceOptions,
  CONJ_ASSOC_OPTIONS,
  DELAY_PLACEMENT_OPTIONS,
  DEFAULT_COMPILE_PROFILE,
  DEFAULT_SOURCE_MODE,
  DISJ_ASSOC_OPTIONS,
  SOURCE_MODE_OPTIONS,
} from './utils/source_defaults.js';
import './styles.css'

function App() {
  const [code, setCode] = useState('');
  const originalCodeRef = useRef('');
  const [selectedExampleId, setSelectedExampleId] = useState('');
  const [sourceMode, setSourceMode] = useState(DEFAULT_SOURCE_MODE);
  const [compileProfile, setCompileProfile] = useState(DEFAULT_COMPILE_PROFILE);
  const [model, setModel] = useState(MODEL_IDS.L4_RAIL_LAZY);
  const [serverModelOptions, setServerModelOptions] = useState([]);
  const [isFrozen, setFrozen] = useState(false);
  const [alert, setAlert] = useState({ isOpen: false, message: '' });
  const treeRef = useRef();
  const {
    tree, stepInfo,
    init, step, reset, back
  } = useStepper({
    onSuccess: () => { setGoalId(null); }
  });
  const [disabled, setDisabled] = useState({
    start: false,
    reset: true,
    back: true,
    step: true,
  });
  const [substitutionData, setSubstitutionData] = useState([]);
  const [trailData, setTrailData] = useState([]);
  const [goalId, setGoalId] = useState(null);
  const [stateId, setStateId] = useState(null);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [isExampleLoading, setIsExampleLoading] = useState(false);
  
  const [ darkMode, setDarkMode ] = useState(false);
  const programmaticCodeUpdateRef = useRef(false);

  const convertExampleToMicro = async (sourceText, profile = compileProfile) => {
    const response = await fetch('api/post/source-convert', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        ...buildSourceOptions(sourceText, DEFAULT_SOURCE_MODE, profile),
        targetSourceMode: "micro",
      }),
      credentials: "include",
    });
    const payload = await response.json();
    if (!response.ok) {
      throw new Error(payload?.error || `Unable to convert example (${response.status})`);
    }
    return payload.source;
  };

  const loadExampleSource = async (
    exampleId,
    nextSourceMode = sourceMode,
    nextCompileProfile = compileProfile,
  ) => {
    const example = exampleById(exampleId);
    if (!example) return null;
    return nextSourceMode === "mini"
      ? example.miniSource
      : convertExampleToMicro(example.miniSource, nextCompileProfile);
  };

  const applyExampleSource = (nextCode, exampleId) => {
    programmaticCodeUpdateRef.current = true;
    setSelectedExampleId(exampleId);
    setCode(nextCode);
  };

  const handleInit = async () => {
    const trimmed = code.trim();
    if (!trimmed) {
      setAlert({ isOpen: true, message: "Program is empty." });
      return;
    }

    originalCodeRef.current = code;
    const [success, progOrError] = await init(code, sourceMode, compileProfile, model);
    if (success) {
      setFrozen(true);
      setCode(progOrError);
      setDisabled({start: true, reset: false, back: true, step: false});
    } else {
      setAlert({ isOpen: true, message: progOrError });
    }
  };
  
  const handleStep = async () => {
    const [success, isDone] = await step();
    if (isDone) { // no more reductions
      setDisabled({start: true, reset: false, back: false, step: true});
    } else if (success) { // success but more reductions
      setDisabled(prev => ({...prev, back: false}));
    }
  };

  const handleBack = async () => {
    const [_, isLast] = await back();
    if (isLast) {  // TODO: Change this to isStart on both sides
      setDisabled(prev => ({...prev, back: true}));
    } else {
      setDisabled(prev => ({...prev, step: false}));
    }
  }

  const handleReset = async () => {
    const success = await reset();  
    if (success) {
      programmaticCodeUpdateRef.current = true;
      setCode(originalCodeRef.current);
      setFrozen(false);
      setDisabled({start: false, reset: true, back: true, step: true});
    }
  }
  
  useEffect(() => {
    if (tree && treeRef.current) {
      treeRef.current.redraw(tree);
      treeRef.current.updateSidebar(stateId);
      }
  }, [tree]);

  useEffect(() => {
    if (isFrozen || !selectedExampleId) {
      setIsExampleLoading(false);
      return undefined;
    }
    let active = true;
    setIsExampleLoading(true);

    const load = async () => {
      try {
        const nextCode = await loadExampleSource(
          selectedExampleId,
          sourceMode,
          compileProfile,
        );
        if (!active || nextCode == null) return;
        applyExampleSource(nextCode, selectedExampleId);
      } catch (err) {
        if (!active) return;
        setAlert({
          isOpen: true,
          message: err?.message || "Unable to load example.",
        });
      } finally {
        if (active) {
          setIsExampleLoading(false);
        }
      }
    };

    load();
    return () => { active = false; };
  }, [selectedExampleId, sourceMode, compileProfile, isFrozen]);

  useEffect(() => {
    if (programmaticCodeUpdateRef.current) {
      programmaticCodeUpdateRef.current = false;
    }
  }, [code]);

  useEffect(() => {
    let active = true;
    const loadModels = async () => {
      try {
        const response = await fetch('api/get/models');
        if (!response.ok) return;
        const models = await response.json();
        if (!Array.isArray(models) || models.length === 0) return;
        const nextOptions = models
          .filter((m) => m && m.id && m.label)
          .map((m) => ({ value: m.id, label: m.label }));
        if (nextOptions.length === 0) return;
        if (!active) return;
        setServerModelOptions(nextOptions);
        setModel((currentModel) =>
          nextOptions.some((opt) => opt.value === currentModel)
            ? currentModel
            : nextOptions[0].value
        );
      } catch (_) {
        // Keep local fallback model options on fetch failure.
      }
    };
    loadModels();
    return () => { active = false; };
  }, []);

  const modelOptions = serverModelOptions.length > 0
    ? serverModelOptions
    : DEFAULT_MODEL_OPTIONS;
  const toolbarDisabled = {
    ...disabled,
    start: disabled.start || (!isFrozen && (code.trim() === "" || isExampleLoading)),
  };

  const handleSourceModeChange = (nextSourceMode) => {
    if (isFrozen) return;
    if (selectedExampleId) {
      setIsExampleLoading(true);
    }
    setSourceMode(nextSourceMode);
  };

  const handleCompileProfileChange = (axis, value) => {
    if (isFrozen) return;
    if (selectedExampleId && sourceMode === "micro") {
      setIsExampleLoading(true);
    }
    setCompileProfile((current) => ({ ...current, [axis]: value }));
  };

  const handleExampleChange = (exampleId) => {
    if (isFrozen) return;
    setIsExampleLoading(Boolean(exampleId));
    setSelectedExampleId(exampleId);
  };

  const handleModelChange = (nextModel) => {
    if (isFrozen) return;
    setModel(nextModel);
  };

  const handleCodeChange = (nextCode) => {
    if (!programmaticCodeUpdateRef.current) {
      setSelectedExampleId("");
    }
    setCode(nextCode);
  };

  return (
    <div className="container">
      <Resizable>
        <div className="input-container">
          <CodeHeader
            logoSrc={darkMode ? "/mk_logo_white.png" : "/mk_logo_black.png"}
            exampleValue={selectedExampleId}
            onExampleChange={handleExampleChange}
            sourceModeValue={sourceMode}
            sourceModeOptions={SOURCE_MODE_OPTIONS}
            onSourceModeChange={handleSourceModeChange}
            compileProfile={compileProfile}
            conjAssocOptions={CONJ_ASSOC_OPTIONS}
            disjAssocOptions={DISJ_ASSOC_OPTIONS}
            delayPlacementOptions={DELAY_PLACEMENT_OPTIONS}
            onCompileProfileChange={handleCompileProfileChange}
            modelValue={model}
            modelOptions={modelOptions}
            onModelChange={handleModelChange}
            isFrozen={isFrozen}
           />
          <div className="editor-area">
            <CodeEditor 
              codeText={code} 
              setCodeText={handleCodeChange}
              isFrozen={isFrozen} 
              isDark={darkMode}
              goalId={goalId}
              onTagClick={setGoalId}
            />
          </div>
          <Toolbar 
            onStart={handleInit}
            onStep={handleStep}
            onBack={handleBack}
            onReset={handleReset}
            disabled={toolbarDisabled}
          />
        </div>
        
        <div className="right-pane">
          <StepInfo {...stepInfo} darkMode={darkMode} setDarkMode={setDarkMode} />
          <Scrollbar style={{ width: '100%', height: '100%' }}>
            <div style={{ display: 'block', width: 'max-content', margin: '0 auto' }}>
              <TreeCanvas 
                ref={treeRef}
                onNodeClick={({ substitutionData, trailData, gId, sId }) => {
                  setSubstitutionData(substitutionData);
                  setTrailData(trailData);
                  setGoalId(gId);
                  setStateId(sId);
                }}
                selectedGoalId={goalId}
                selectedStateId={stateId}
                />
            </div>
          </Scrollbar>
        </div>
      </Resizable>  
      <Sidebar
        substitutionData={substitutionData} 
        trailData={trailData} 
        isOpen={sidebarOpen}
        onToggle={() => setSidebarOpen(o => !o)}
      />
      <CustomAlert
        isOpen={alert.isOpen}
        message={alert.message}
        onClose={() => setAlert({ isOpen: false, message: '' })}
      />
    </div>
  );
}

export default App;
