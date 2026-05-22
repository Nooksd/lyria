import { useEffect, useState } from "react";
import api from "../services/api";
import { useToast, ToastContainer } from "../components/Toast";

interface ArtistRequest {
  _id: string;
  spotifyUrl: string;
  spotifyArtistId: string;
  artistName: string;
  avatarUrl: string;
  status: string;
  requestedBy: string;
  requestedByName?: string;
  createdAt: string;
  reviewedAt?: string;
}

export default function Requests() {
  const [requests, setRequests] = useState<ArtistRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState("pending");
  const [processing, setProcessing] = useState<string | null>(null);
  const [autoAcceptEnabled, setAutoAcceptEnabled] = useState(false);
  const [autoAcceptLoading, setAutoAcceptLoading] = useState(false);
  const { toasts, show } = useToast();

  useEffect(() => {
    loadRequests();
  }, [filter]);

  useEffect(() => {
    loadAutoAcceptStatus();
  }, []);

  const loadRequests = async () => {
    setLoading(true);
    try {
      const params = filter ? `?status=${filter}` : "";
      const res = await api.get(`/admin/artist-requests${params}`);
      setRequests(res.data.requests || []);
    } catch {
      show("Erro ao carregar solicitações", "error");
    } finally {
      setLoading(false);
    }
  };

  const loadAutoAcceptStatus = async () => {
    try {
      const res = await api.get("/admin/artist-requests/autoaccept");
      setAutoAcceptEnabled(Boolean(res.data.enabled));
    } catch {
      // Keep the requests screen usable if this status call fails.
    }
  };

  const toggleAutoAccept = async () => {
    setAutoAcceptLoading(true);
    try {
      const res = await api.post("/admin/artist-requests/autoaccept", {
        enabled: !autoAcceptEnabled,
      });
      setAutoAcceptEnabled(Boolean(res.data.enabled));
      const approved = Number(res.data.approved || 0);
      show(
        res.data.enabled
          ? approved > 0
            ? `Autoaccept ativado. ${approved} solicitações aprovadas.`
            : "Autoaccept ativado"
          : "Autoaccept desativado",
      );
      loadRequests();
    } catch {
      show("Erro ao alterar autoaccept", "error");
    } finally {
      setAutoAcceptLoading(false);
    }
  };

  const handleApprove = async (id: string) => {
    setProcessing(id);
    try {
      await api.post(`/admin/artist-requests/${id}/approve`);
      show("Solicitação aprovada e importação iniciada");
      loadRequests();
    } catch {
      show("Erro ao aprovar solicitação", "error");
    } finally {
      setProcessing(null);
    }
  };

  const handleReject = async (id: string, name: string) => {
    if (!confirm(`Rejeitar solicitação de "${name}"?`)) return;
    setProcessing(id);
    try {
      await api.post(`/admin/artist-requests/${id}/reject`);
      show("Solicitação rejeitada");
      loadRequests();
    } catch {
      show("Erro ao rejeitar solicitação", "error");
    } finally {
      setProcessing(null);
    }
  };

  const statusLabel = (status: string) => {
    switch (status) {
      case "pending":
        return { text: "Pendente", color: "var(--warning)" };
      case "approved":
        return { text: "Aprovada", color: "var(--success)" };
      case "rejected":
        return { text: "Rejeitada", color: "var(--danger)" };
      default:
        return { text: status, color: "var(--text-muted)" };
    }
  };

  return (
    <>
      <ToastContainer toasts={toasts} />

      <div className="page-header">
        <h1>Solicitações de Artistas</h1>
        <div
          style={{
            display: "flex",
            gap: 16,
            alignItems: "center",
            flexWrap: "wrap",
          }}
        >
          <label
            style={{
              display: "flex",
              alignItems: "center",
              gap: 8,
              cursor: autoAcceptLoading ? "wait" : "pointer",
              userSelect: "none",
              fontSize: 14,
              fontWeight: 500,
            }}
          >
            <span>Autoaccept</span>
            <div
              onClick={autoAcceptLoading ? undefined : toggleAutoAccept}
              style={{
                width: 44,
                height: 24,
                borderRadius: 12,
                background: autoAcceptEnabled
                  ? "var(--accent)"
                  : "var(--bg-input)",
                position: "relative",
                transition: "background 0.2s ease",
                border: "1px solid var(--border)",
                opacity: autoAcceptLoading ? 0.5 : 1,
              }}
            >
              <div
                style={{
                  width: 18,
                  height: 18,
                  borderRadius: "50%",
                  background: "#fff",
                  position: "absolute",
                  top: 2,
                  left: autoAcceptEnabled ? 22 : 2,
                  transition: "left 0.2s ease",
                  boxShadow: "0 1px 3px rgba(0,0,0,.3)",
                }}
              />
            </div>
          </label>
          <div style={{ display: "flex", gap: 8 }}>
            {["pending", "approved", "rejected", ""].map((s) => (
              <button
                key={s}
                className={`btn btn-sm ${filter === s ? "btn-primary" : "btn-ghost"}`}
                onClick={() => setFilter(s)}
              >
                {s === ""
                  ? "Todas"
                  : s === "pending"
                    ? "Pendentes"
                    : s === "approved"
                      ? "Aprovadas"
                      : "Rejeitadas"}
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="card">
        {loading ? (
          <div className="loading">
            <div className="spinner" /> Carregando...
          </div>
        ) : requests.length === 0 ? (
          <div className="empty-state">
            <p>
              Nenhuma solicitação{" "}
              {filter === "pending" ? "pendente" : "encontrada"}.
            </p>
          </div>
        ) : (
          <div className="table-wrapper">
            <table>
              <thead>
                <tr>
                  <th style={{ width: 48 }}></th>
                  <th>Artista</th>
                  <th>Solicitado por</th>
                  <th>Status</th>
                  <th>Data</th>
                  {filter === "pending" && <th>Ações</th>}
                </tr>
              </thead>
              <tbody>
                {requests.map((r) => {
                  const st = statusLabel(r.status);
                  return (
                    <tr key={r._id}>
                      <td>
                        {r.avatarUrl ? (
                          <img
                            src={r.avatarUrl}
                            alt={r.artistName}
                            style={{
                              width: 40,
                              height: 40,
                              borderRadius: "50%",
                              objectFit: "cover",
                            }}
                            onError={(e) => {
                              (e.target as HTMLImageElement).style.display =
                                "none";
                            }}
                          />
                        ) : (
                          <span
                            style={{
                              width: 40,
                              height: 40,
                              display: "inline-block",
                              borderRadius: "50%",
                              background: "var(--bg-hover)",
                            }}
                          />
                        )}
                      </td>
                      <td>
                        <div style={{ fontWeight: 500 }}>
                          {r.artistName || "Desconhecido"}
                        </div>
                        <a
                          href={r.spotifyUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          style={{ fontSize: 12, color: "var(--accent)" }}
                        >
                          Ver no Spotify ↗
                        </a>
                      </td>
                      <td style={{ color: "var(--text-muted)" }}>
                        {r.requestedByName || r.requestedBy}
                      </td>
                      <td>
                        <span
                          style={{
                            padding: "2px 10px",
                            borderRadius: 9999,
                            fontSize: 12,
                            fontWeight: 500,
                            background: `${st.color}22`,
                            color: st.color,
                            border: `1px solid ${st.color}44`,
                          }}
                        >
                          {st.text}
                        </span>
                      </td>
                      <td style={{ color: "var(--text-muted)", fontSize: 13 }}>
                        {new Date(r.createdAt).toLocaleDateString("pt-BR")}
                      </td>
                      {filter === "pending" && (
                        <td>
                          <div style={{ display: "flex", gap: 8 }}>
                            <button
                              className="btn btn-primary btn-sm"
                              disabled={processing === r._id}
                              onClick={() => handleApprove(r._id)}
                            >
                              {processing === r._id ? "..." : "Aprovar"}
                            </button>
                            <button
                              className="btn btn-danger btn-sm"
                              disabled={processing === r._id}
                              onClick={() => handleReject(r._id, r.artistName)}
                            >
                              Rejeitar
                            </button>
                          </div>
                        </td>
                      )}
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </>
  );
}
