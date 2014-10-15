theory Packet_Set
imports Fixed_Action "Output_Format/Negation_Type_Matching" Datatype_Selectors
begin

section{*Packet Set*}
(*probably everything here wants a simple ruleset*)

text{*@{const alist_and} transforms @{typ "'a negation_type list \<Rightarrow> 'a match_expr"} and uses conjunction as connective. *}

subsection{*Executable Packet Set Representation*}

text{*based on @{file "Negation_Type_DNF.thy"}*}

(*
text{*Symbolic (executable) representation. inner is @{text \<and>}, outer is @{text \<or>}*}
datatype_new 'a packet_set = PacketSet (packet_set_repr: "('a negation_type list) list")

(*generalize remove unknown matches*)

(*irgendwie muss hier \<gamma> a rein
TODO: first remove all unknowns?
*)
definition to_packet_set :: "'a match_expr \<Rightarrow> 'a packet_set" where
 "to_packet_set m = PacketSet (map to_negation_type_nnf (normalize_match m))"

definition packet_set_to_set :: "('a, 'packet) match_tac \<Rightarrow> action \<Rightarrow> 'a packet_set \<Rightarrow> 'packet set" where
  "packet_set_to_set \<gamma> a ps \<equiv> {p. \<exists> as \<in> set (packet_set_repr ps). matches \<gamma> (alist_and as) a p}"

lemma to_packet_set_correct: "p \<in> packet_set_to_set \<gamma> a (to_packet_set m) \<longleftrightarrow> matches \<gamma> m a p"
apply(simp add: to_packet_set_def packet_set_to_set_def)
apply(rule iffI)
 apply(clarify)
 apply(induction m rule: normalize_match.induct)
       apply(simp_all add: bunch_of_lemmata_about_matches)
 apply (smt2 alist_and_append imageE matches_simp2 matches_simp22 to_negation_type_nnf.simps(4))
apply (metis matches_DeMorgan)
apply(induction m rule: normalize_match.induct)
      apply(simp_all add: bunch_of_lemmata_about_matches)
 apply (metis alist_and_append matches_simp1)
apply (metis Un_iff matches_DeMorgan)
done

(*'a packet_set \<Rightarrow> 'a packet_set*)
fun packet_set_filter :: "('a, 'p) match_tac \<Rightarrow> action \<Rightarrow> ('p \<Rightarrow> bool) \<Rightarrow> ('a negation_type list) list \<Rightarrow> ('a negation_type list) list" where
  "packet_set_filter _ _ _ [] = []" |
  "packet_set_filter \<gamma> a f (n#ns) = [] @ packet_set_filter \<gamma> a f ns"
*)

text{*Symbolic (executable) representation. inner is @{text \<and>}, outer is @{text \<or>}*}
(*we remember the action which might be necessary for applying \<alpha>*)
datatype_new 'a packet_set = PacketSet (packet_set_repr: "(('a negation_type \<times> action) list) list")

definition to_packet_set :: "action \<Rightarrow> 'a match_expr \<Rightarrow> 'a packet_set" where
 "to_packet_set a m = PacketSet (map (map (\<lambda>m'. (m',a)) o to_negation_type_nnf) (normalize_match m))"

definition packet_set_to_set :: "('a, 'packet) match_tac \<Rightarrow> 'a packet_set \<Rightarrow> 'packet set" where
  "packet_set_to_set \<gamma> ps \<equiv> \<Union> ms \<in> set (packet_set_repr ps).  {p. \<forall> (m, a) \<in> set ms. matches \<gamma> (negation_type_to_match_expr m) a p}"

lemma to_packet_set_correct: "p \<in> packet_set_to_set \<gamma> (to_packet_set a m) \<longleftrightarrow> matches \<gamma> m a p"
apply(simp add: to_packet_set_def packet_set_to_set_def)
apply(rule iffI)
 apply(clarify)
 apply(induction m rule: normalize_match.induct)
       apply(simp_all add: bunch_of_lemmata_about_matches)
   apply force
apply (metis matches_DeMorgan)
apply(induction m rule: normalize_match.induct)
      apply(simp_all add: bunch_of_lemmata_about_matches)
 apply (metis Un_iff)
apply (metis Un_iff matches_DeMorgan)
done

lemma to_packet_set_set: "packet_set_to_set \<gamma> (to_packet_set a m) = {p. matches \<gamma> m a p}"
using to_packet_set_correct by fast


text{*If the matching agrees for two actions, then the packet sets are also equal*}
lemma "\<forall>p. matches \<gamma> m a1 p \<longleftrightarrow> matches \<gamma> m a2 p \<Longrightarrow> packet_set_to_set \<gamma> (to_packet_set a1 m) = packet_set_to_set \<gamma> (to_packet_set a2 m)"
apply(subst(asm) to_packet_set_correct[symmetric])+
apply safe
apply simp_all
done

fun packet_set_and :: "'a packet_set \<Rightarrow> 'a packet_set \<Rightarrow> 'a packet_set" where
  "packet_set_and (PacketSet olist1) (PacketSet olist2) = PacketSet [andlist1 @ andlist2. andlist1 <- olist1, andlist2 <- olist2]"

value "packet_set_and (PacketSet [[a,b], [c,d]]) (PacketSet [[v,w], [x,y]])"

declare packet_set_and.simps[simp del]

lemma packet_set_and_correct: "packet_set_to_set \<gamma> (packet_set_and (to_packet_set a m1) (to_packet_set a m2)) = packet_set_to_set \<gamma> (to_packet_set a (MatchAnd m1 m2))"
 apply(simp add: to_packet_set_def packet_set_and.simps packet_set_to_set_def)
 by fast
 
lemma packet_set_and_correct': "p \<in> packet_set_to_set \<gamma> (packet_set_and (to_packet_set a m1) (to_packet_set a m2)) \<longleftrightarrow> matches \<gamma> (MatchAnd m1 m2) a p"
apply(simp add: to_packet_set_correct[symmetric])
using packet_set_and_correct by fast

(*TODO move*)
lemma packet_set_to_set_alt:  "packet_set_to_set \<gamma> ps = (\<Union> ms \<in> set (packet_set_repr ps).  {p. \<forall> m a. (m, a) \<in> set ms \<longrightarrow> matches \<gamma> (negation_type_to_match_expr m) a p})"
unfolding packet_set_to_set_def
by fast

lemma packet_set_and_union: "packet_set_to_set \<gamma> (packet_set_and P1 P2) = packet_set_to_set \<gamma> P1 \<inter> packet_set_to_set \<gamma> P2"
unfolding packet_set_to_set_def
 apply(cases P1)
 apply(cases P2)
 apply(simp)
 apply(simp add: packet_set_and.simps)
 apply blast
done



definition packet_set_constrain :: "action \<Rightarrow> 'a match_expr \<Rightarrow> 'a packet_set \<Rightarrow> 'a packet_set" where
  "packet_set_constrain a m ns = packet_set_and ns (to_packet_set a m)"


lemma packet_set_constrain_correct: "packet_set_to_set \<gamma> (packet_set_constrain a m P) = {p \<in> packet_set_to_set \<gamma> P. matches \<gamma> m a p}"
unfolding packet_set_constrain_def
unfolding packet_set_and_union
unfolding to_packet_set_set
by blast


lemma packet_set_append:
  "packet_set_to_set \<gamma> (PacketSet (p1 @ p2)) = packet_set_to_set \<gamma> (PacketSet p1) \<union> packet_set_to_set \<gamma> (PacketSet p2)"
  by(simp add: packet_set_to_set_def)

lemma packet_set_cons: "packet_set_to_set \<gamma> (PacketSet (a # p3)) =  packet_set_to_set \<gamma> (PacketSet [a]) \<union> packet_set_to_set \<gamma> (PacketSet p3)"
  by(simp add: packet_set_to_set_def)

fun listprepend :: "'a list \<Rightarrow> 'a list list \<Rightarrow> 'a list list" where
  "listprepend [] ns = []" |
  "listprepend (a#as) ns = (map (\<lambda>xs. a#xs) ns) @ (listprepend as ns)"

lemma packet_set_map_a_and: "packet_set_to_set \<gamma> (PacketSet (map (op # a) ds)) = packet_set_to_set \<gamma> (PacketSet [[a]]) \<inter> packet_set_to_set \<gamma> (PacketSet ds)"
  apply(induction ds)
   apply(simp_all add: packet_set_to_set_def)
  apply(case_tac a)
   apply(simp_all)
   apply blast+
  done
lemma listprepend_correct: "packet_set_to_set \<gamma> (PacketSet (listprepend as ds)) = packet_set_to_set \<gamma> (PacketSet (map (\<lambda>a. [a]) as)) \<inter> packet_set_to_set \<gamma> (PacketSet ds)"
  apply(induction as arbitrary: )
   apply(simp add: packet_set_to_set_alt)
  apply(simp)
  apply(rename_tac a as)
  apply(simp add: packet_set_map_a_and packet_set_append)
  (*using packet_set_cons by fast*)
  apply(subst(2) packet_set_cons)
  by blast

(*begin scratch*)
(*
fun invertt :: "('a negation_type \<times> action) \<Rightarrow> ('a negation_type \<times> action)" where
  "invertt (Pos n, a) = (Neg n, a)" |
  "invertt (Neg n, a) = (Pos n, a)"

lemma "packet_set_to_set \<gamma> (PacketSet [[invertt n]]) = UNIV - packet_set_to_set \<gamma> (PacketSet [[n]])"
nitpick
oops

fun packet_set_not_internal :: " ('a negation_type \<times> action) list list \<Rightarrow>  ('a negation_type \<times> action) list list" where
  "packet_set_not_internal [] = [[]]" |
  "packet_set_not_internal (ns#nss) = listprepend (map (\<lambda>(n,a). (invert n,a)) ns) (packet_set_not_internal nss)"


lemma "packet_set_to_set \<gamma> (PacketSet (packet_set_not_internal d)) = UNIV - packet_set_to_set \<gamma> (PacketSet d)"
nitpick
(*unknown inverting is wrong\<And>*)
  apply(induction d)
   apply(simp add: packet_set_to_set_alt)
  apply(simp add: )
  apply(simp add: listprepend_correct)
  apply(simp add: packet_set_to_set_alt)
  apply safe
  apply simp_all
  
  apply(simp add: cnf_invert_singelton cnf_singleton_false)
  done

fun packet_set_not :: "'a packet_set \<Rightarrow> 'a packet_set" where
  "packet_set_not (PacketSet ps) = PacketSet [map (\<lambda>(n,a). (invert n,a)) ns. ns <- ps]"
declare packet_set_not.simps[simp del]

lemma "packet_set_to_set \<gamma> (packet_set_not P) = - packet_set_to_set \<gamma> P"
apply(cases P)
apply(simp)
apply(simp add: packet_set_not.simps)
apply(simp add: packet_set_to_set_alt)
apply(safe)

oops
(*end scratch*)
*)




subsection{*The set of all accepted packets*}
text{*
Collect all packets which are allowed by the firewall.
*}
fun collect_allow :: "('a, 'p) match_tac \<Rightarrow> 'a rule list \<Rightarrow> 'p set \<Rightarrow> 'p set" where
  "collect_allow _ [] P = {}" |
  "collect_allow \<gamma> ((Rule m Accept)#rs) P = {p \<in> P. matches \<gamma> m Accept p} \<union> (collect_allow \<gamma> rs {p \<in> P. \<not> matches \<gamma> m Accept p})" |
  "collect_allow \<gamma> ((Rule m Drop)#rs) P = (collect_allow \<gamma> rs {p \<in> P. \<not> matches \<gamma> m Drop p})"

lemma collect_allow_subset: "simple_ruleset rs \<Longrightarrow> collect_allow \<gamma> rs P \<subseteq> P"
apply(induction rs arbitrary: P)
 apply(simp)
apply(rename_tac r rs P)
apply(case_tac r, rename_tac m a)
apply(case_tac a)
apply(simp_all add: simple_ruleset_def)
apply(fast)
apply blast
done


lemma collect_allow_sound: "simple_ruleset rs \<Longrightarrow> p \<in> collect_allow \<gamma> rs P \<Longrightarrow> approximating_bigstep_fun \<gamma> p rs Undecided = Decision FinalAllow"
proof(induction rs arbitrary: P)
case Nil thus ?case by simp
next
case (Cons r rs)
  from Cons obtain m a where r: "r = Rule m a" by (cases r) simp
  from Cons.prems have simple_rs: "simple_ruleset rs" by (simp add: r simple_ruleset_def)
  from Cons.prems r have a_cases: "a = Accept \<or> a = Drop" by (simp add: r simple_ruleset_def)
  show ?case (is ?goal)
  proof(cases a)
    case Accept
      from Accept Cons.IH[where P="{p \<in> P. \<not> matches \<gamma> m Accept p}"] simple_rs have IH:
        "p \<in> collect_allow \<gamma> rs {p \<in> P. \<not> matches \<gamma> m Accept p} \<Longrightarrow> approximating_bigstep_fun \<gamma> p rs Undecided = Decision FinalAllow" by simp
      from Accept Cons.prems have "(p \<in> P \<and> matches \<gamma> m Accept p) \<or> p \<in> collect_allow \<gamma> rs {p \<in> P. \<not> matches \<gamma> m Accept p}"
        by(simp add: r)
      with Accept show ?goal
      apply -
      apply(erule disjE)
       apply(simp add: r)
      apply(simp add: r)
      using IH by blast
    next
    case Drop 
      from Drop Cons.prems have "p \<in> collect_allow \<gamma> rs {p \<in> P. \<not> matches \<gamma> m Drop p}"
        by(simp add: r)
      with Cons.IH simple_rs have "approximating_bigstep_fun \<gamma> p rs Undecided = Decision FinalAllow" by simp
      with Cons show ?goal
       apply(simp add: r Drop del: approximating_bigstep_fun.simps)
       apply(simp)
       using collect_allow_subset[OF simple_rs] by fast
    qed(insert a_cases, simp_all)
qed


lemma collect_allow_complete: "simple_ruleset rs \<Longrightarrow> approximating_bigstep_fun \<gamma> p rs Undecided = Decision FinalAllow \<Longrightarrow> p \<in> P \<Longrightarrow> p \<in> collect_allow \<gamma> rs P"
proof(induction rs arbitrary: P)
case Nil thus ?case by simp
next
case (Cons r rs)
  from Cons obtain m a where r: "r = Rule m a" by (cases r) simp
  from Cons.prems have simple_rs: "simple_ruleset rs" by (simp add: r simple_ruleset_def)
  from Cons.prems r have a_cases: "a = Accept \<or> a = Drop" by (simp add: r simple_ruleset_def)
  show ?case (is ?goal)
  proof(cases a)
    case Accept
      from Accept Cons.IH simple_rs have IH: "\<forall>P. approximating_bigstep_fun \<gamma> p rs Undecided = Decision FinalAllow \<longrightarrow> p \<in> P \<longrightarrow> p \<in> collect_allow \<gamma> rs P" by simp
      with Accept Cons.prems show ?goal
        apply(cases "matches \<gamma> m Accept p")
         apply(simp add: r)
        apply(simp add: r)
        done
    next
    case Drop
      with Cons show ?goal 
        apply(case_tac "matches \<gamma> m Drop p")
         apply(simp add: r)
        apply(simp add: r simple_rs)
        done
    qed(insert a_cases, simp_all)
qed


theorem collect_allow_sound_complete: "simple_ruleset rs \<Longrightarrow> {p. p \<in> collect_allow \<gamma> rs UNIV} = {p. approximating_bigstep_fun \<gamma> p rs Undecided = Decision FinalAllow}"
apply(safe)
using collect_allow_sound[where P=UNIV] apply fast
using collect_allow_complete[where P=UNIV] by fast

end
