# Feedback de dano

- `hit_feedback_profile.gd` define o Resource `HitFeedbackProfile`, com os parâmetros do hitstop, empurrão, flash, deformação, recuo e tremor.
- `hit_feedback.gd` solicita a pausa à `ActorStateMachine` depois de um dano aceito e calcula a velocidade horizontal do empurrão. O ator aplica essa velocidade ao próprio corpo físico, inclusive durante o hitstop.
- `hit_feedback_view.gd` aplica o flash e a deformação à raiz visual do alvo. No atacante, desloca essa raiz e fornece o tremor em pixels para a câmera. Os efeitos avançam nos ticks que o ator já executa.
- `hit_flash.gdshader` desenha o branco sobre as malhas e usa a máscara alfa dos sprites 3D com amostragem Nearest. A apresentação guarda os materiais temporários por ator e restaura os overlays anteriores ao fim do flash.

Para integrar uma entidade, dispare `receive` no componente de lógica e na apresentação após a redução de HP. A apresentação recebe a raiz de malhas e sprites 3D separada do colisor. Consuma o hitstop antes de avançar o estado e use o empurrão na movimentação física. Para o atacante, chame `confirm` apenas quando o alvo confirmar o dano e leia o deslocamento da câmera na View.
