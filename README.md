# TempoAlerta

## Backend (Python)
    cd backend
    python -m venv venv && venv\Scripts\activate     # Linux/Mac: source venv/bin/activate
    pip install -r requirements.txt
    uvicorn main:app --host 0.0.0.0 --port 8000 --reload
Docs interativos: http://localhost:8000/docs

## App (Flutter)
    flutter create --org br.edu.ugv --project-name tempoalerta app_tmp
    copie app_tmp/android, app_tmp/ios (e demais pastas de plataforma) para app/
    cd app && flutter pub get && flutter run
No AndroidManifest.xml (android/app/src/main/), na tag <application>, adicione:
    android:usesCleartextTraffic="true"
e antes dela: <uses-permission android:name="android.permission.INTERNET"/>
Em celular físico, troque 10.0.2.2 por o IP do PC em lib/services/api.dart.
